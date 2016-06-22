import Foundation

/// The socket which encapsulates the logic to handle connection to proxies.
class ProxySocket: NSObject, SocketProtocol, RawTCPSocketDelegate {
    /// Received `ConnectRequest`.
    var request: ConnectRequest?

    /**
     Init a `ProxySocket` with a raw TCP socket.

     - parameter socket: The raw TCP socket.
     */
    init(socket: RawTCPSocketProtocol) {
        self.socket = socket
        super.init()
        self.socket.delegate = self
    }

    /**
     Begin reading and processing data from the socket.
     */
    func openSocket() {
    }

    /**
     Response to the `ConnectResponse` from `AdapterSocket` on the other side of the `Tunnel`.

     - parameter response: The `ConnectResponse`.
     */
    func respondToResponse(response: ConnectResponse) {
    }

    // MARK: SocketProtocol Implemention

    /// The underlying TCP socket transmitting data.
    var socket: RawTCPSocketProtocol!

    /// The delegate instance.
    weak var delegate: SocketDelegate?

    /// Every delegate method should be called on this dispatch queue. And every method call and variable access will be called on this queue.
    var queue: dispatch_queue_t! {
        didSet {
            socket.queue = queue
        }
    }

    /// The current connection status of the socket.
    var state: SocketStatus = .Established


    // MARK: RawTCPSocketDelegate Protocol Implemention
    /**
     The socket did disconnect.

     - parameter socket: The socket which did disconnect.
     */
    func didDisconnect(socket: RawTCPSocketProtocol) {
        state = .Closed
        delegate?.didDisconnect(self)
    }

    /**
     The socket did read some data.

     - parameter data:    The data read from the socket.
     - parameter withTag: The tag given when calling the `readData` method.
     - parameter from:    The socket where the data is read from.
     */
    func didReadData(data: NSData, withTag tag: Int, from: RawTCPSocketProtocol) {}

    /**
     The socket did send some data.

     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter withTag: The tag given when calling the `writeData` method.
     - parameter from:    The socket where the data is sent out.
     */
    func didWriteData(data: NSData?, withTag tag: Int, from: RawTCPSocketProtocol) {}

    /**
     The socket did connect to remote.

     - note: This never happens for `ProxySocket`.

     - parameter socket: The connected socket.
     */
    func didConnect(socket: RawTCPSocketProtocol) {

    }
}
