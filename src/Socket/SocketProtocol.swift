import Foundation

/**
 The current connection status of the socket.

 - Invalid:       The socket is just created but never connects.
 - Connecting:    The socket is connecting.
 - Established:   The connection is established.
 - Disconnecting: The socket is disconnecting.
 - Closed:        The socket is closed.
 */
enum SocketStatus {
    /// The socket is just created but never connects.
    case Invalid,

    /// The socket is connecting.
    Connecting,

    /// The connection is established.
    Established,

    /// The socket is disconnecting.
    Disconnecting,

    /// The socket is closed.
    Closed
}

/// Protocol for socket with various functions.
///
/// Any concrete implemention does not need to be thread-safe.
///
/// - warning: It is expected that the instance is accessed on the `queue` only.
protocol SocketProtocol: class {
    /// The underlying TCP socket transmitting data.
    var socket: RawTCPSocketProtocol! { get }

    /// The delegate instance.
    var delegate: SocketDelegate? { get set }

    /// /// Every delegate method should be called on this dispatch queue. And every method call and variable access will be called on this queue.
    var queue: dispatch_queue_t! { get set }

    /// The current connection status of the socket.
    var state: SocketStatus { get set }
}

extension SocketProtocol {
    /// If the socket is disconnected.
    var isDisconnected: Bool {
        return state == .Closed || state == .Invalid
    }

    /**
     Send data to remote.

     - parameter data: Data to send.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    func writeData(data: NSData, withTag tag: Int = 0) {
        socket.writeData(data, withTag: tag)
    }

//    func readDataToLength(length: Int, withTag tag: Int) {
//        socket.readDataToLength(length, withTag: tag)
//    }
//
//    func readDataToData(data: NSData, withTag tag: Int) {
//        socket.readDataToData(data, withTag: tag)
//    }

    /**
     Read data from the socket.

     - parameter tag: The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataWithTag(tag: Int = 0) {
        socket.readDataWithTag(tag)
    }

    /**
     Disconnect the socket elegantly.
     */
    func disconnect() {
        state = .Disconnecting
        socket.disconnect()
    }

    /**
     Disconnect the socket immediately.
     */
    func forceDisconnect() {
        state = .Disconnecting
        socket.forceDisconnect()
    }
}

/// The delegate protocol to handle the events from a socket.
protocol SocketDelegate : class {
    /**
     The socket did connect to remote.

     - parameter socket: The connected socket.
     */
    func didConnect(adapterSocket: AdapterSocket, withResponse: ConnectResponse)

    /**
     The socket did disconnect.

     This should only be called once in the entire lifetime of a socket. After this is called, the delegate will not receive any other events from that socket and the socket should be released.

     - parameter socket: The socket which did disconnect.
     */
    func didDisconnect(socket: SocketProtocol)

    /**
     The socket did read some data.

     - parameter data:    The data read from the socket.
     - parameter withTag: The tag given when calling the `readData` method.
     - parameter from:    The socket where the data is read from.
     */
    func didReadData(data: NSData, withTag: Int, from: SocketProtocol)

    /**
     The socket did send some data.

     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter withTag: The tag given when calling the `writeData` method.
     - parameter from:    The socket where the data is sent out.
     */
    func didWriteData(data: NSData?, withTag: Int, from: SocketProtocol)

    /**
     The socket is ready to forward data back and forth.

     - parameter socket: The socket becomes ready to forward data.
     */
    func readyToForward(socket: SocketProtocol)

    /**
     Did receive a `ConnectRequest` from local that it is time to connect to remote.

     - parameter request: The received `ConnectRequest`.
     - parameter from:    The socket where the `ConnectRequest` is received.
     */
    func didReceiveRequest(request: ConnectRequest, from: ProxySocket)

    /**
     The socket decided to use a new `AdapterSocket` to connect to remote.

     - parameter newAdapter: The new `AdapterSocket` to replace the old one.
     */
    func updateAdapter(newAdapter: AdapterSocket)
}

extension SocketDelegate {
    func didReceiveRequest(request: ConnectRequest, from: ProxySocket) {}

    func didConnect(adapterSocket: AdapterSocket, withResponse: ConnectResponse) {}
}
