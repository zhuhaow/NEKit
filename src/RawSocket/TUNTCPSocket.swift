import Foundation
import tun2socks

/// The TCP socket build upon `TSTCPSocket`.
///
/// - warning: This class is not thread-safe.
public class TUNTCPSocket: RawTCPSocketProtocol, TSTCPSocketDelegate {
    fileprivate let tsSocket: TSTCPSocket
    fileprivate var reading = false
    fileprivate var pendingReadData: Data = Data()
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

    // MARK: RawTCPSocketProtocol implementation

    /// The `RawTCPSocketDelegate` instance.
    public weak var delegate: RawTCPSocketDelegate?

    /// If the socket is connected.
    public var isConnected: Bool {
        return tsSocket.isConnected
    }

    /// The source address.
    public var sourceIPAddress: IPAddress? {
        return IPAddress(fromInAddr: tsSocket.sourceAddress)
    }

    /// The source port.
    public var sourcePort: Port? {
        return Port(port: tsSocket.sourcePort)
    }

    /// The destination address.
    public var destinationIPAddress: IPAddress? {
        return IPAddress(fromInAddr: tsSocket.destinationAddress)
    }

    /// The destination port.
    public var destinationPort: Port? {
        return Port(port: tsSocket.destinationPort)
    }

    /// `TUNTCPSocket` cannot connect to anything actively, this is just a stub method.
    ///
    /// - Parameters:
    ///   - host: host
    ///   - port: port
    ///   - enableTLS: enableTLS
    ///   - tlsSettings: tlsSettings
    /// - Throws: Never throws anything.
    public func connectTo(host: String, port: Int, enableTLS: Bool, tlsSettings: [AnyHashable: Any]?) throws {}

    /**
     Disconnect the socket.

     The socket will disconnect elegantly after any queued writing data are successfully sent.
     */
    public func disconnect() {
        if !isConnected {
            delegate?.didDisconnectWith(socket: self)
        } else {
            closeAfterWriting = true
            checkStatus()
        }
    }

    /**
     Disconnect the socket immediately.
     */
    public func forceDisconnect() {
        if !isConnected {
            delegate?.didDisconnectWith(socket: self)
        } else {
            tsSocket.close()
        }
    }

    /**
     Send data to local.

     - parameter data: Data to send.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    public func write(data: Data) {
        remainWriteLength = data.count
        tsSocket.writeData(data)
    }

    /**
     Read data from the socket.

     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    public func readData() {
        reading = true
        checkReadData()
    }

    /**
     Read specific length of data from the socket.

     - parameter length: The length of the data to read.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    public func readDataTo(length: Int) {
        readLength = length
        reading = true
        checkReadData()
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    public func readDataTo(data: Data) {
        readDataTo(data: data, maxLength: 0)
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter maxLength: Ignored since `GCDAsyncSocket` does not support this. The max length of data to scan for the pattern.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    public func readDataTo(data: Data, maxLength: Int) {
        reading = true
        scanner = StreamScanner(pattern: data, maximumLength: maxLength)
        checkReadData()
    }

    fileprivate func queueCall(_ block: @escaping () -> Void) {
        QueueFactory.getQueue().async(execute: block)
    }

    fileprivate func checkReadData() {
        if pendingReadData.count > 0 {
            queueCall {
                guard self.reading else {
                    // no queued read request
                    return
                }

                if let readLength = self.readLength {
                    if self.pendingReadData.count >= readLength {
                        let returnData = self.pendingReadData.subdata(in: 0..<readLength)
                        self.pendingReadData = self.pendingReadData.subdata(in: readLength..<self.pendingReadData.count)

                        self.readLength = nil
                        self.delegate?.didRead(data: returnData, from: self)
                        self.reading = false
                    }
                } else if let scanner = self.scanner {
                    guard let (match, rest) = scanner.addAndScan(self.pendingReadData) else {
                        return
                    }

                    self.scanner = nil

                    guard let matchData = match else {
                        // do not find match in the given length, stop now
                        return
                    }

                    self.pendingReadData = rest
                    self.delegate?.didRead(data: matchData, from: self)
                    self.reading = false
                } else {
                    self.delegate?.didRead(data: self.pendingReadData, from: self)
                    self.pendingReadData = Data()
                    self.reading = false
                }
            }
        }
    }

    fileprivate func checkStatus() {
        if closeAfterWriting && remainWriteLength == 0 {
            forceDisconnect()
        }
    }

    // MARK: TSTCPSocketDelegate implementation
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
            self.delegate?.didDisconnectWith(socket: self)
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

                self.delegate?.didWrite(data: nil, by: self)
                self.checkStatus()
            }
        }
    }
}
