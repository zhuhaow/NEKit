import Foundation
import NetworkExtension
import CocoaLumberjackSwift

/// The TCP socket build upon `NWTCPConnection`.
///
/// - warning: This class is not thread-safe, it is expected that the instance is accessed on the `queue` only.
class NWTCPSocket: NSObject, RawTCPSocketProtocol {
    static let ScannerReadTag = 10000
    private var connection: NWTCPConnection!

    private var writePending = false
    private var closeAfterWriting = false

    private var scanner: StreamScanner!
    private var scannerTag: Int!
    private var readDataPrefix: NSData?

    // MARK: RawTCPSocketProtocol implemention

    /// The `RawTCPSocketDelegate` instance.
    weak var delegate: RawTCPSocketDelegate?

    /// Every method call and variable access must operated on this queue. And all delegate methods will be called on this queue.
    ///
    /// - warning: This should be set as soon as the instance is initialized.
    var queue: dispatch_queue_t!

    /// If the socket is connected.
    var isConnected: Bool {
        return connection.state == .Connected
    }

    /// The source address.
    ///
    /// - note: Always returns `nil`.
    var sourceIPAddress: IPv4Address? {
        return nil
    }

    /// The source port.
    ///
    /// - note: Always returns `nil`.
    var sourcePort: Port? {
        return nil
    }

    /// The destination address.
    ///
    /// - note: Always returns `nil`.
    var destinationIPAddress: IPv4Address? {
        return nil
    }

    /// The destination port.
    ///
    /// - note: Always returns `nil`.
    var destinationPort: Port? {
        return nil
    }

    /**
     Connect to remote host.

     - parameter host:        Remote host.
     - parameter port:        Remote port.
     - parameter enableTLS:   Should TLS be enabled.
     - parameter tlsSettings: The settings of TLS.

     - throws: Never throws.
     */
    func connectTo(host: String, port: Int, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) throws {
        let endpoint = NWHostEndpoint(hostname: host, port: "\(port)")
        let tlsParameters = NWTLSParameters()
        if let tlsSettings = tlsSettings as? [String: AnyObject] {
            tlsParameters.setValuesForKeysWithDictionary(tlsSettings)
        }

        connection = NetworkInterface.TunnelProvider.createTCPConnectionToEndpoint(endpoint, enableTLS: enableTLS, TLSParameters: tlsParameters, delegate: nil)
        connection.addObserver(self, forKeyPath: "state", options: [.Initial, .New], context: nil)
    }

    /**
     Disconnect the socket.

     The socket will disconnect elegantly after any queued writing data are successfully sent.
     */
    func disconnect() {
        closeAfterWriting = true
        checkStatus()
    }

    /**
     Disconnect the socket immediately.
     */
    func forceDisconnect() {
        cancel()
    }

    /**
     Send data to remote.

     - parameter data: Data to send.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    func writeData(data: NSData, withTag tag: Int) {
        sendData(data, withTag: tag)
    }

    /**
     Read data from the socket.

     - parameter tag: The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataWithTag(tag: Int) {
        connection.readMinimumLength(1, maximumLength: Opt.MAXNWTCPSocketReadDataSize) { data, error in
            guard error == nil else {
                DDLogError("NWTCPSocket got an error when reading data: \(error)")
                return
            }

            self.readCallback(data, tag: tag)
        }
    }

    /**
     Read specific length of data from the socket.

     - parameter length: The length of the data to read.
     - parameter tag:    The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataToLength(length: Int, withTag tag: Int) {
        connection.readLength(length) { data, error in
            guard error == nil else {
                DDLogError("NWTCPSocket got an error when reading data: \(error)")
                return
            }

            self.readCallback(data, tag: tag)
        }
    }

    // Actually, this method is available as `- (void)readToPattern:(id)arg1 maximumLength:(unsigned int)arg2 completionHandler:(id /* block */)arg3;`
    // which is sadly not available in public header for some reason I don't know.
    // I don't want to do it myself since This method is not trival to implement and I don't like reinventing the wheel.
    // Here is only the most naive version, which may not be the optimal if using with large data blocks.
    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataToData(data: NSData, withTag tag: Int) {
        scanner = StreamScanner(pattern: data, maximumLength: Opt.MAXNWTCPScanLength)
        scannerTag = tag
        readDataWithTag(NWTCPSocket.ScannerReadTag)
    }

    private func queueCall(block: ()->()) {
        dispatch_async(queue, block)
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard keyPath == "state" else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            return
        }

        guard let change = change else {
            return
        }

        DDLogVerbose("\(change)")
        //        if let newValue = change[NSKeyValueChangeNewKey] as? NWTCPConnectionState {
        //
        //        }

        DDLogVerbose("SNWTunnel state changed to \(connection.state.rawValue).")

        switch connection.state {
        case .Connected:
            queueCall {
                self.delegate?.didConnect(self)
            }
        case .Disconnected:
            DDLogVerbose("Disconnected")
            cancel()
        case .Cancelled:
            DDLogVerbose("Cancelled")
            queueCall {
                self.delegate?.didDisconnect(self)
                self.delegate = nil
            }
        default:
            DDLogVerbose("SNWTunnel state is \(connection.state.rawValue).")
            break
        }
    }

    private func readCallback(data: NSData?, tag: Int) {
        queueCall {
            guard let data = self.consumeReadData(data) else {
                // remote read is closed, but this is okay, nothing need to be done, if this socket is read again, then error occurs.
                return
            }

            if tag == NWTCPSocket.ScannerReadTag {
                guard let (match, rest) = self.scanner.addAndScan(data) else {
                    self.readDataWithTag(NWTCPSocket.ScannerReadTag)
                    return
                }

                self.scanner = nil

                guard let matchData = match else {
                    // do not find match in the given length, stop now
                    return
                }

                self.readDataPrefix = rest
                self.delegate?.didReadData(matchData, withTag: self.scannerTag, from: self)
            } else {
                self.delegate?.didReadData(data, withTag: tag, from: self)
            }
        }
    }

    private func sendData(data: NSData, withTag tag: Int) {
        writePending = true
        self.connection.write(data) { error in
            self.writePending = false

            guard error == nil else {
                DDLogError("NWTCPSocket got an error when writing data: \(error)")
                self.disconnect()
                return
            }

            self.queueCall {
                self.delegate?.didWriteData(data, withTag: tag, from: self)
            }
            self.checkStatus()
        }
    }

    private func consumeReadData(data: NSData?) -> NSData? {
        defer {
            readDataPrefix = nil
        }

        if readDataPrefix == nil {
            return data
        }

        if data == nil {
            return readDataPrefix
        }

        let wholeData = NSMutableData(data: readDataPrefix!)
        wholeData.appendData(data!)
        return NSData(data: wholeData)
    }

    private func cancel() {
        connection.cancel()
    }

    private func checkStatus() {
        if closeAfterWriting && !writePending {
            cancel()
        }
    }
}
