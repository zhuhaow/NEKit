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
/// Any concrete implemention does not need to be thread-safe.
///
/// - warning: It is expected that the instance is accessed on the `queue` only.
public protocol SocketProtocol: class {
    /// The underlying TCP socket transmitting data.
    var socket: RawTCPSocketProtocol! { get }

    /// The delegate instance.
    var delegate: SocketDelegate? { get set }

    /// Every delegate method should be called on this dispatch queue. And every method call and variable access will be called on this queue.
    var queue: DispatchQueue! { get set }

    /// The current connection status of the socket.
    var status: SocketStatus { get set }

    /// If the socket is disconnected.
    var isDisconnected: Bool { get }

    /// The type of the socket.
    var typeName: String { get }

    /**
     Read data from the socket.

     - parameter tag: The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataWithTag(_ tag: Int)

    /**
     Send data to remote.

     - parameter data: Data to send.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    func writeData(_ data: Data, withTag tag: Int)

    /**
     Disconnect the socket elegantly.
     */
    func disconnect()

    /**
     Disconnect the socket immediately.
     */
    func forceDisconnect()
}

extension SocketProtocol {
    /// If the socket is disconnected.
    public var isDisconnected: Bool {
        return status == .closed || status == .invalid
    }

    public var typeName: String {
        return String(describing: type(of: self))
    }
}

/// The delegate protocol to handle the events from a socket.
public protocol SocketDelegate : class {
    /**
     The socket did connect to remote.

     - parameter socket: The connected socket.
     */
    func didConnect(_ adapterSocket: AdapterSocket, withResponse: ConnectResponse)

    /**
     The socket did disconnect.

     This should only be called once in the entire lifetime of a socket. After this is called, the delegate will not receive any other events from that socket and the socket should be released.

     - parameter socket: The socket which did disconnect.
     */
    func didDisconnect(_ socket: SocketProtocol)

    /**
     The socket did read some data.

     - parameter data:    The data read from the socket.
     - parameter withTag: The tag given when calling the `readData` method.
     - parameter from:    The socket where the data is read from.
     */
    func didReadData(_ data: Data, withTag: Int, from: SocketProtocol)

    /**
     The socket did send some data.

     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter withTag: The tag given when calling the `writeData` method.
     - parameter from:    The socket where the data is sent out.
     */
    func didWriteData(_ data: Data?, withTag: Int, from: SocketProtocol)

    /**
     The socket is ready to forward data back and forth.

     - parameter socket: The socket becomes ready to forward data.
     */
    func readyToForward(_ socket: SocketProtocol)

    /**
     Did receive a `ConnectRequest` from local that it is time to connect to remote.

     - parameter request: The received `ConnectRequest`.
     - parameter from:    The socket where the `ConnectRequest` is received.
     */
    func didReceiveRequest(_ request: ConnectRequest, from: ProxySocket)

    /**
     The socket decided to use a new `AdapterSocket` to connect to remote.

     - parameter newAdapter: The new `AdapterSocket` to replace the old one.
     */
    func updateAdapter(_ newAdapter: AdapterSocket)
}
