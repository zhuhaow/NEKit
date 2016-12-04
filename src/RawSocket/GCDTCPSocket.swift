import Foundation
import CocoaAsyncSocket

/// The TCP socket build upon `GCDAsyncSocket`.
///
/// - warning: This class is not thread-safe, it is expected that the instance is accessed on the `queue` only.
open class GCDTCPSocket: NSObject, GCDAsyncSocketDelegate, RawTCPSocketProtocol {
    fileprivate let socket: GCDAsyncSocket
    fileprivate var enableTLS: Bool = false

    /**
     Initailize an instance with `GCDAsyncSocket`.

     - parameter socket: The socket object to work with. If this is `nil`, then a new `GCDAsyncSocket` instance is created.
     */
    public init(socket: GCDAsyncSocket? = nil) {
        if let socket = socket {
            self.socket = socket
        } else {
            self.socket = GCDAsyncSocket()
        }
        super.init()
    }

    // MARK: RawTCPSocketProtocol implementation

    /// The `RawTCPSocketDelegate` instance.
    weak open var delegate: RawTCPSocketDelegate?

    /// Every method call and variable access must operated on this queue. And all delegate methods will be called on this queue.
    ///
    /// - warning: This should be set as soon as the instance is initialized.
    open var queue: DispatchQueue! = nil {
        didSet {
            socket.setDelegate(self, delegateQueue: queue)
        }
    }

    /// If the socket is connected.
    open var isConnected: Bool {
        return !socket.isDisconnected
    }

    /// The source address.
    open var sourceIPAddress: IPv4Address? {
        guard let localHost = socket.localHost else {
            return nil
        }
        return IPv4Address(fromString: localHost)
    }

    /// The source port.
    open var sourcePort: Port? {
        return Port(port: socket.localPort)
    }

    /// The destination address.
    ///
    /// - note: Always returns `nil`.
    open var destinationIPAddress: IPv4Address? {
        return nil
    }

    /// The destination port.
    ///
    /// - note: Always returns `nil`.
    open var destinationPort: Port? {
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
    open func connectTo(host: String, port: Int, enableTLS: Bool = false, tlsSettings: [AnyHashable: Any]? = nil) throws {
        try connectTo(host: host, withPort: port)
        self.enableTLS = enableTLS
        if enableTLS {
            startTLSWith(settings: tlsSettings)
        }
    }

    /**
     Disconnect the socket.

     The socket will disconnect elegantly after any queued writing data are successfully sent.
     */
    open func disconnect() {
        socket.disconnectAfterWriting()
    }

    /**
     Disconnect the socket immediately.
     */
    open func forceDisconnect() {
        socket.disconnect()
    }

    /**
     Send data to remote.

     - parameter data: Data to send.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    open func write(data: Data) {
        write(data: data, withTimeout: -1)
    }

    /**
     Read data from the socket.

     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    open func readData() {
        socket.readData(withTimeout: -1, tag: 0)
    }

    /**
     Read specific length of data from the socket.

     - parameter length: The length of the data to read.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    open func readDataTo(length: Int) {
        readDataTo(length: length, withTimeout: -1)
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    open func readDataTo(data: Data) {
        readDataTo(data: data, maxLength: 0)
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter maxLength: Ignored since `GCDAsyncSocket` does not support this. The max length of data to scan for the pattern.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    open func readDataTo(data: Data, maxLength: Int) {
        readDataTo(data: data, withTimeout: -1)
    }

    // MARK: Other helper methods
    /**
     Send data to remote.

     - parameter data: Data to send.
     - parameter timeout: Operation timeout.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    func write(data: Data, withTimeout timeout: Double) {
        socket.write(data, withTimeout: timeout, tag: 0)
    }

    /**
     Read specific length of data from the socket.

     - parameter length: The length of the data to read.
     - parameter timeout: Operation timeout.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataTo(length: Int, withTimeout timeout: Double) {
        socket.readData(toLength: UInt(length), withTimeout: timeout, tag: 0)
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter timeout: Operation timeout.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataTo(data: Data, withTimeout timeout: Double) {
        socket.readData(to: data, withTimeout: timeout, tag: 0)
    }

    /**
     Connect to remote host.

     - parameter host:        Remote host.
     - parameter port:        Remote port.

     - throws: The error occured when connecting to host.
     */
    func connectTo(host: String, withPort port: Int) throws {
        try socket.connect(toHost: host, onPort: UInt16(port))
    }

    /**
     Secures the connection using SSL/TLS.

     - parameter tlsSettings: TLS settings, refer to documents of `GCDAsyncSocket` for detail.
     */
    func startTLSWith(settings: [AnyHashable: Any]!) {
        if let settings = settings as? [String: NSNumber] {
            socket.startTLS(settings)
        } else {
            socket.startTLS(nil)
        }
    }

    // MARK: Delegate methods for GCDAsyncSocket
    open func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        delegate?.didWrite(data: nil, by: self)
    }

    open func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        delegate?.didRead(data: data, from: self)
    }

    open func socketDidDisconnect(_ socket: GCDAsyncSocket, withError err: Error?) {
        delegate?.didDisconnectWith(socket: self)
        delegate = nil
        socket.setDelegate(nil, delegateQueue: nil)
    }

    open func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        if !enableTLS {
            delegate?.didConnectWith(socket: self)
        }
    }

    open func socketDidSecure(_ sock: GCDAsyncSocket) {
        if enableTLS {
            delegate?.didConnectWith(socket: self)
        }
    }

}
