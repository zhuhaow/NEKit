import Foundation
import CocoaAsyncSocket

/// The TCP socket build upon `GCDAsyncSocket`.
///
/// - warning: This class is not thread-safe, it is expected that the instance is accessed on the `queue` only.
class GCDTCPSocket: NSObject, GCDAsyncSocketDelegate, RawTCPSocketProtocol {
    private let socket: GCDAsyncSocket
    private var enableTLS: Bool = false

    /**
     Initailize an instance with `GCDAsyncSocket`.

     - parameter socket: The socket object to work with. If this is `nil`, then a new `GCDAsyncSocket` instance is created.
     */
    init(socket: GCDAsyncSocket? = nil) {
        if let socket = socket {
            self.socket = socket
        } else {
            self.socket = GCDAsyncSocket()
        }
        super.init()
    }

    // MARK: RawTCPSocketProtocol implemention

    /// The `RawTCPSocketDelegate` instance.
    weak var delegate: RawTCPSocketDelegate?

    /// Every method call and variable access must operated on this queue. And all delegate methods will be called on this queue.
    ///
    /// - warning: This should be set as soon as the instance is initialized.
    var queue: dispatch_queue_t! = nil {
        didSet {
            socket.setDelegate(self, delegateQueue: queue)
        }
    }

    /// If the socket is connected.
    var isConnected: Bool {
        return !socket.isDisconnected
    }

    /// The source address.
    var sourceIPAddress: IPv4Address? {
        guard let localHost = socket.localHost else {
            return nil
        }
        return IPv4Address(fromString: localHost)
    }

    /// The source port.
    var sourcePort: Port? {
        return Port(port: socket.localPort)
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

     - throws: The error occured when connecting to host.
     */
    func connectTo(host: String, port: Int, enableTLS: Bool = false, tlsSettings: [NSObject : AnyObject]? = nil) throws {
        try connectToHost(host, withPort: port)
        self.enableTLS = enableTLS
        if enableTLS {
            startTLS(tlsSettings)
        }
    }

    /**
     Disconnect the socket.

     The socket will disconnect elegantly after any queued writing data are successfully sent.
     */
    func disconnect() {
        socket.disconnectAfterWriting()
    }

    /**
     Disconnect the socket immediately.
     */
    func forceDisconnect() {
        socket.disconnect()
    }

    /**
     Send data to remote.

     - parameter data: Data to send.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    func writeData(data: NSData, withTag tag: Int) {
        writeData(data, withTimeout: -1, withTag: tag)
    }

    /**
     Read data from the socket.

     - parameter tag: The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataWithTag(tag: Int) {
        socket.readDataWithTimeout(-1, tag: tag)
    }

    /**
     Read specific length of data from the socket.

     - parameter length: The length of the data to read.
     - parameter tag:    The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataToLength(length: Int, withTag tag: Int) {
        readDataToLength(length, withTimeout: -1, withTag: tag)
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataToData(data: NSData, withTag tag: Int) {
        readDataToData(data, withTag: tag, maxLength: 0)
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - parameter maxLength: Ignored since `GCDAsyncSocket` does not support this. The max length of data to scan for the pattern.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataToData(data: NSData, withTag tag: Int, maxLength: Int) {
        readDataToData(data, withTimeout: -1, withTag: tag)
    }

    // MARK: Other helper methods
    /**
     Send data to remote.

     - parameter data: Data to send.
     - parameter timeout: Operation timeout.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    func writeData(data: NSData, withTimeout timeout: Double, withTag tag: Int) {
        socket.writeData(data, withTimeout: timeout, tag: tag)
    }

    /**
     Read specific length of data from the socket.

     - parameter length: The length of the data to read.
     - parameter timeout: Operation timeout.
     - parameter tag:    The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataToLength(length: Int, withTimeout timeout: Double, withTag tag: Int) {
        socket.readDataToLength(UInt(length), withTimeout: timeout, tag: tag)
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter timeout: Operation timeout.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataToData(data: NSData, withTimeout timeout: Double, withTag tag: Int) {
        socket.readDataToData(data, withTimeout: timeout, tag: tag)
    }

    /**
     Connect to remote host.

     - parameter host:        Remote host.
     - parameter port:        Remote port.

     - throws: The error occured when connecting to host.
     */
    func connectToHost(host: String, withPort port: Int) throws {
        try socket.connectToHost(host, onPort: UInt16(port))
    }

    /**
     Secures the connection using SSL/TLS.

     - parameter tlsSettings: TLS settings, refer to documents of `GCDAsyncSocket` for detail.
     */
    func startTLS(tlsSettings: [NSObject : AnyObject]!) {
        if let settings = tlsSettings as? [String: NSNumber] {
            socket.startTLS(settings)
        } else {
            socket.startTLS(nil)
        }
    }

    // MARK: Delegate methods for GCDAsyncSocket
    func socket(sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        delegate?.didWriteData(nil, withTag: tag, from: self)
    }

    func socket(sock: GCDAsyncSocket, didReadData data: NSData, withTag tag: Int) {
        delegate?.didReadData(data, withTag: tag, from: self)
    }

    func socketDidDisconnect(socket: GCDAsyncSocket, withError err: NSError?) {
        delegate?.didDisconnect(self)
        delegate = nil
        socket.setDelegate(nil, delegateQueue: nil)
    }

    func socket(sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        if !enableTLS {
            delegate?.didConnect(self)
        }
    }

    func socketDidSecure(sock: GCDAsyncSocket) {
        if enableTLS {
            delegate?.didConnect(self)
        }
    }

}
