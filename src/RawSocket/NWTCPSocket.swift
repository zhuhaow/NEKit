import Foundation
import NetworkExtension
import CocoaLumberjackSwift

class NWTCPSocket: NSObject, RawTCPSocketProtocol {
    static let ScannerReadTag = 10000

    weak var delegate: RawTCPSocketDelegate?

    var connection: NWTCPConnection!
    var delegateQueue: dispatch_queue_t!

    var writePending = false
    var closeAfterWriting = false

    var scanner: StreamScanner!
    var scannerTag: Int!
    var readDataPrefix: NSData?

    var isConnected: Bool {
        return connection.state == .Connected
    }

    var sourceIPAddress: IPv4Address? {
        return nil
    }

    var sourcePort: Port? {
        return nil
    }

    var destinationIPAddress: IPv4Address? {
        return nil
    }

    var destinationPort: Port? {
        return nil
    }


    var cancelledSignaled = false

    // MARK: SocketProtocol implemention
    func connectTo(host: String, port: Int, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) {
        let endpoint = NWHostEndpoint(hostname: host, port: "\(port)")
        let tlsParameters = NWTLSParameters()
        if let tlsSettings = tlsSettings as? [String: AnyObject] {
            tlsParameters.setValuesForKeysWithDictionary(tlsSettings)
        }

        connection = NetworkInterface.TunnelProvider.createTCPConnectionToEndpoint(endpoint, enableTLS: enableTLS, TLSParameters: tlsParameters, delegate: nil)
        connection.addObserver(self, forKeyPath: "state", options: [.Initial, .New], context: nil)
    }

    func disconnect() {
        closeAfterWriting = true
        checkStatus()
    }

    func forceDisconnect() {
        cancel()
    }

    func writeData(data: NSData, withTag tag: Int) {
        sendData(data, withTag: tag)
    }

    func readDataWithTag(tag: Int) {
        connection.readMinimumLength(1, maximumLength: Opt.MAXNWTCPSocketReadDataSize) { data, error in
            guard error == nil else {
                DDLogError("NWTCPSocket got an error when reading data: \(error)")
                return
            }

            self.readCallback(data, tag: tag)
        }
    }

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
    func readDataToData(data: NSData, withTag tag: Int) {
        scanner = StreamScanner(pattern: data, maximumLength: Opt.MAXNWTCPScanLength)
        scannerTag = tag
        readDataWithTag(NWTCPSocket.ScannerReadTag)
    }

    private func delegateCall(block: ()->()) {
        dispatch_async(delegateQueue, block)
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
            delegateCall() {
                self.delegate?.didConnect(self)
            }
        case .Disconnected:
            DDLogVerbose("Disconnected")
            cancel()
        case .Cancelled:
            DDLogVerbose("Cancelled")
            if !cancelledSignaled {
                cancelledSignaled = true
                delegateCall() {
                    self.delegate?.didDisconnect(self)
                }
            }
        default:
            DDLogVerbose("SNWTunnel state is \(connection.state.rawValue).")
            break
        }
    }

    private func readCallback(data: NSData?, tag: Int) {
        delegateCall {
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

            self.delegateCall() {
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
    
    deinit {
        connection?.removeObserver(self, forKeyPath: "state")
    }
}
