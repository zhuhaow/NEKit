import Foundation

/**
 The current connection status of the socket.

 - Invalid:       The socket is just created but never connects.
 - Connecting:    The socket is connecting.
 - Established:   The connection is established.
 - Disconnecting: The socket is disconnecting.
 - Closed:        The socket is closed.
 */
public enum SocketStatus {
    /// The socket is just created but never connects.
    case invalid,

    /// The socket is connecting.
    connecting,

    /// The connection is established.
    established,

    /// The socket is disconnecting.
    disconnecting,

    /// The socket is closed.
    closed
}

/// Protocol for socket with various functions.
///
/// Any concrete implementation does not need to be thread-safe.
public protocol SocketProtocol: class {
    /// The underlying TCP socket transmitting data.
    var socket: RawTCPSocketProtocol! { get }

    /// The delegate instance.
    weak var delegate: SocketDelegate? { get set }

    /// The current connection status of the socket.
    var status: SocketStatus { get }

//    /// The description of the currect status.
//    var statusDescription: String { get }

    /// If the socket is disconnected.
    var isDisconnected: Bool { get }

    /// The type of the socket.
    var typeName: String { get }

    var readStatusDescription: String { get }

    var writeStatusDescription: String { get }

    /**
     Read data from the socket.

     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readData()

    /**
     Send data to remote.

     - parameter data: Data to send.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    func write(data: Data)

    /**
     Disconnect the socket elegantly.
     */
    func disconnect(becauseOf error: Error?)

    /**
     Disconnect the socket immediately.
     */
    func forceDisconnect(becauseOf error: Error?)
}

extension SocketProtocol {
    /// If the socket is disconnected.
    public var isDisconnected: Bool {
        return status == .closed || status == .invalid
    }

    public var typeName: String {
        return String(describing: type(of: self))
    }

    public var readStatusDescription: String {
        return "\(status)"
    }

    public var writeStatusDescription: String {
        return "\(status)"
    }
}

/// The delegate protocol to handle the events from a socket.
public protocol SocketDelegate : class {
    /**
     The socket did connect to remote.

     - parameter adapterSocket: The connected socket.
     */
    func didConnectWith(adapterSocket: AdapterSocket)

    /**
     The socket did disconnect.

     This should only be called once in the entire lifetime of a socket. After this is called, the delegate will not receive any other events from that socket and the socket should be released.

     - parameter socket: The socket which did disconnect.
     */
    func didDisconnectWith(socket: SocketProtocol)

    /**
     The socket did read some data.

     - parameter data:    The data read from the socket.
     - parameter from:    The socket where the data is read from.
     */
    func didRead(data: Data, from: SocketProtocol)

    /**
     The socket did send some data.

     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter by:      The socket where the data is sent out.
     */
    func didWrite(data: Data?, by: SocketProtocol)

    /**
     The socket is ready to forward data back and forth.

     - parameter socket: The socket which becomes ready to forward data.
     */
    func didBecomeReadyToForwardWith(socket: SocketProtocol)

    /**
     Did receive a `ConnectSession` from local now it is time to connect to remote.

     - parameter session: The received `ConnectSession`.
     - parameter from:    The socket where the `ConnectSession` is received.
     */
    func didReceive(session: ConnectSession, from: ProxySocket)

    /**
     The adapter socket decided to replace itself with a new `AdapterSocket` to connect to remote.

     - parameter newAdapter: The new `AdapterSocket` to replace the old one.
     */
    func updateAdapterWith(newAdapter: AdapterSocket)
}
