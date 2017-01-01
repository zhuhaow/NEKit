import Foundation
import CocoaAsyncSocket

/// The TCP socket build upon `GCDAsyncSocket`.
///
/// - warning: This class is not thread-safe.
public class GCDTCPSocket: NSObject, GCDAsyncSocketDelegate, RawTCPSocketProtocol {
    private let socket: GCDAsyncSocket
    private var enableTLS: Bool = false

    /**
     Initailize an instance with `GCDAsyncSocket`.

     - parameter socket: The socket object to work with. If this is `nil`, then a new `GCDAsyncSocket` instance is created.
     */
    public init(socket: GCDAsyncSocket? = nil) {
        if let socket = socket {
            self.socket = socket
            self.socket.setDelegate(nil, delegateQueue: QueueFactory.getQueue())
        } else {
            self.socket = GCDAsyncSocket(delegate: nil, delegateQueue: QueueFactory.getQueue(), socketQueue: QueueFactory.getQueue())
        }
        super.init()

        self.socket.synchronouslySetDelegate(self)
    }

    // MARK: RawTCPSocketProtocol implementation

    /// The `RawTCPSocketDelegate` instance.
    weak public var delegate: RawTCPSocketDelegate?

    /// If the socket is connected.
    public var isConnected: Bool {
        return !socket.isDisconnected
    }

    /// The source address.
    public var sourceIPAddress: IPAddress? {
        guard let localHost = socket.localHost else {
            return nil
        }
        return IPAddress(fromString: localHost)
    }

    /// The source port.
    public var sourcePort: Port? {
        return Port(port: socket.localPort)
    }

    /// The destination address.
    ///
    /// - note: Always returns `nil`.
    public var destinationIPAddress: IPAddress? {
        return nil
    }

    /// The destination port.
    ///
    /// - note: Always returns `nil`.
    public var destinationPort: Port? {
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
    public func connectTo(host: String, port: Int, enableTLS: Bool = false, tlsSettings: [AnyHashable: Any]? = nil) throws {
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
    public func disconnect() {
        socket.disconnectAfterWriting()
    }

    /**
     Disconnect the socket immediately.
     */
    public func forceDisconnect() {
        socket.disconnect()
    }

    /**
     Send data to remote.

     - parameter data: Data to send.
     */
    public func write(data: Data) {
        write(data: data, withTimeout: -1)
    }

    /**
     Read data from the socket.
     */
    public func readData() {
        socket.readData(withTimeout: -1, tag: 0)
    }

    /**
     Read specific length of data from the socket.

     - parameter length: The length of the data to read.
     */
    public func readDataTo(length: Int) {
        readDataTo(length: length, withTimeout: -1)
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     */
    public func readDataTo(data: Data) {
        readDataTo(data: data, maxLength: 0)
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter maxLength: Ignored since `GCDAsyncSocket` does not support this. The max length of data to scan for the pattern.
     */
    public func readDataTo(data: Data, maxLength: Int) {
        readDataTo(data: data, withTimeout: -1)
    }

    // MARK: Other helper methods
    /**
     Send data to remote.

     - parameter data: Data to send.
     - parameter timeout: Operation timeout.
     */
    func write(data: Data, withTimeout timeout: Double) {
        guard data.count > 0 else {
            QueueFactory.getQueue().async {
                self.delegate?.didWrite(data: data, by: self)
            }
            return
        }

        socket.write(data, withTimeout: timeout, tag: 0)
    }

    /**
     Read specific length of data from the socket.

     - parameter length: The length of the data to read.
     - parameter timeout: Operation timeout.
     */
    func readDataTo(length: Int, withTimeout timeout: Double) {
        socket.readData(toLength: UInt(length), withTimeout: timeout, tag: 0)
    }

    /**
     Read data until a specific pattern (including the pattern).

     - parameter data: The pattern.
     - parameter timeout: Operation timeout.
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
    public func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        delegate?.didWrite(data: nil, by: self)
    }

    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        delegate?.didRead(data: data, from: self)
    }

    public func socketDidDisconnect(_ socket: GCDAsyncSocket, withError err: Error?) {
        delegate?.didDisconnectWith(socket: self)
        delegate = nil
        socket.setDelegate(nil, delegateQueue: nil)
    }

    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        if !enableTLS {
            delegate?.didConnectWith(socket: self)
        }
    }

    public func socketDidSecure(_ sock: GCDAsyncSocket) {
        if enableTLS {
            delegate?.didConnectWith(socket: self)
        }
    }

}
