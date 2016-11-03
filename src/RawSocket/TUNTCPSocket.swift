import Foundation
import tun2socks

/// The TCP socket build upon `TSTCPSocket`.
///
/// - warning: This class is not thread-safe, it is expected that the instance is accessed on the `queue` only.
open class TUNTCPSocket: RawTCPSocketProtocol, TSTCPSocketDelegate {
    fileprivate let tsSocket: TSTCPSocket
    fileprivate var readTag: Int?
    fileprivate var pendingReadData: Data = Data()
    fileprivate var writeTag: Int!
    fileprivate var remainWriteLength: Int = 0
    fileprivate var closeAfterWriting = false

    fileprivate var scanner: StreamScanner?

    fileprivate var readLength: Int?

    /**
     Initailize an instance with `TSTCPSocket`.

     - parameter socket: The socket object to work with.
     */
    public init(socket: TSTCPSocket) {
        tsSocket = socket
        tsSocket.delegate = self
    }

    // MARK: RawTCPSocketProtocol implemention

    /// The `RawTCPSocketDelegate` instance.
    open weak var delegate: RawTCPSocketDelegate?

    /// Every method call and variable access must operated on this queue. And all delegate methods will be called on this queue.
    ///
    /// - warning: This should be set as soon as the instance is initialized.
    open var queue: DispatchQueue!

    /// If the socket is connected.
    open var isConnected: Bool {
        return tsSocket.isConnected
    }

    /// The source address.
    open var sourceIPAddress: IPv4Address? {
        return IPv4Address(fromInAddr: tsSocket.sourceAddress)
    }

    /// The source port.
    open var sourcePort: Port? {
        return Port(port: tsSocket.sourcePort)
    }

    /// The destination address.
    open var destinationIPAddress: IPv4Address? {
        return IPv4Address(fromInAddr: tsSocket.destinationAddress)
    }

    /// The destination port.
    open var destinationPort: Port? {
        return Port(port: tsSocket.destinationPort)
    }

    /**
     `TUNTCPSocket` cannot connect to anything actively, this is just a stub method.
     */
    open func connectTo(_ host: String, port: Int, enableTLS: Bool, tlsSettings: [AnyHashable: Any]?) throws {}

    /**
     Disconnect the socket.

     The socket will disconnect elegantly after any queued writing data are successfully sent.
     */
    open func disconnect() {
        if !isConnected {
            delegate?.didDisconnect(self)
        } else {
            closeAfterWriting = true
            checkStatus()
        }
    }

    /**
     Disconnect the socket immediately.
     */
    open func forceDisconnect() {
        if !isConnected {
            delegate?.didDisconnect(self)
        } else {
            tsSocket.close()
        }
    }

    /**
     Send data to local.

     - parameter data: Data to send.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    open func writeData(_ data: Data, withTag tag: Int) {
        writeTag = tag
        remainWriteLength = data.count
        tsSocket.writeData(data)
    }

    /**
     Read data from the socket.

     - parameter tag: The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    open func readDataWithTag(_ tag: Int) {
        readTag = tag
        checkReadData()
    }

    /**
     Read specific length of data from the socket.

     - parameter length: The length of the data to read.
     - parameter tag:    The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    open func readDataToLength(_ length: Int, withTag tag: Int) {
        readLength = length
        readTag = tag
        checkStatus()
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    open func readDataToData(_ data: Data, withTag tag: Int) {
        readDataToData(data, withTag: tag, maxLength: 0)
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - parameter maxLength: Ignored since `GCDAsyncSocket` does not support this. The max length of data to scan for the pattern.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    open func readDataToData(_ data: Data, withTag tag: Int, maxLength: Int) {
        readTag = tag
        scanner = StreamScanner(pattern: data, maximumLength: maxLength)
        checkStatus()
    }

    fileprivate func queueCall(_ block: @escaping ()->()) {
        queue.async(execute: block)
    }

    fileprivate func checkReadData() {
        if pendingReadData.count > 0 {
            queueCall {
                // the didReadData might change the `readTag`
                guard let tag = self.readTag else {
                    // no queued read request
                    return
                }

                if let readLength = self.readLength {
                    if self.pendingReadData.count >= readLength {
                        let returnData = self.pendingReadData.subdata(in: 0..<readLength)
                        self.pendingReadData = self.pendingReadData.subdata(in: readLength..<self.pendingReadData.count)

                        self.readLength = nil
                        self.delegate?.didReadData(returnData, withTag: tag, from: self)
                        self.readTag = nil
                    }
                } else if let scanner = self.scanner {
                    guard let (match, rest) = scanner.addAndScan(self.pendingReadData) else {
                        return
                    }

                    self.scanner = nil
                    self.readTag = nil

                    guard let matchData = match else {
                        // do not find match in the given length, stop now
                        return
                    }

                    self.pendingReadData = rest
                    self.delegate?.didReadData(matchData, withTag: tag, from: self)
                } else {
                    self.readTag = nil
                    self.delegate?.didReadData(self.pendingReadData, withTag: tag, from: self)
                    self.pendingReadData = Data()
                }
            }
        }
    }

    fileprivate func checkStatus() {
        if closeAfterWriting && remainWriteLength == 0 {
            forceDisconnect()
        }
    }

    // MARK: TSTCPSocketDelegate implemention
    // The local stop sending anything.
    // Theoretically, the local may still be reading data from remote.
    // However, there is simply no way to know if the local is still open, so we can only assume that the local side close tx only when it decides that it does not need to read anymore.
    open func localDidClose(_ socket: TSTCPSocket) {
        disconnect()
    }

    open func socketDidReset(_ socket: TSTCPSocket) {
        socketDidClose(socket)
    }

    open func socketDidAbort(_ socket: TSTCPSocket) {
        socketDidClose(socket)
    }

    open func socketDidClose(_ socket: TSTCPSocket) {
        queueCall {
            self.delegate?.didDisconnect(self)
            self.delegate = nil
        }
    }

    open func didReadData(_ data: Data, from: TSTCPSocket) {
        queueCall {
            self.pendingReadData.append(data)
            self.checkReadData()
        }
    }

    open func didWriteData(_ length: Int, from: TSTCPSocket) {
        queueCall {
            self.remainWriteLength -= length
            if self.remainWriteLength <= 0 {

                self.delegate?.didWriteData(nil, withTag: self.writeTag, from: self)
                self.checkStatus()
            }
        }
    }
}
