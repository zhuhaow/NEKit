import Foundation

/// The socket which encapsulates the logic to handle connection to proxies.
open class ProxySocket: NSObject, SocketProtocol, RawTCPSocketDelegate {
    /// Received `ConnectRequest`.
    open var request: ConnectRequest?

    open var observer: Observer<ProxySocketEvent>?

    /// If the socket is disconnected.
    open var isDisconnected: Bool {
        return state == .closed || state == .invalid
    }

    open override var description: String {
        if let request = request {
            return "<\(type) host:\(request.host) port: \(request.port))>"
        } else {
            return "<\(type)>"
        }
    }

    open let type: String

    /**
     Init a `ProxySocket` with a raw TCP socket.

     - parameter socket: The raw TCP socket.
     */
    init(socket: RawTCPSocketProtocol) {
        self.socket = socket
        type = "\(type(of: self))"

        super.init()

        self.socket.delegate = self
        observer = ObserverFactory.currentFactory?.getObserverForProxySocket(self)
    }

    /**
     Begin reading and processing data from the socket.
     */
    func openSocket() {
        observer?.signal(.socketOpened(self))
    }

    /**
     Response to the `ConnectResponse` from `AdapterSocket` on the other side of the `Tunnel`.

     - parameter response: The `ConnectResponse`.
     */
    func respondToResponse(_ response: ConnectResponse) {
        observer?.signal(.receivedResponse(response, on: self))
    }

    /**
     Read data from the socket.

     - parameter tag: The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    open func readDataWithTag(_ tag: Int) {
        socket.readDataWithTag(tag)
    }

    /**
     Send data to remote.

     - parameter data: Data to send.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    open func writeData(_ data: Data, withTag tag: Int) {
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
     Disconnect the socket elegantly.
     */
    open func disconnect() {
        state = .disconnecting
        socket.disconnect()
        observer?.signal(.disconnectCalled(self))
    }

    /**
     Disconnect the socket immediately.
     */
    open func forceDisconnect() {
        state = .disconnecting
        socket.forceDisconnect()
        observer?.signal(.forceDisconnectCalled(self))
    }


    // MARK: SocketProtocol Implemention

    /// The underlying TCP socket transmitting data.
    open var socket: RawTCPSocketProtocol!

    /// The delegate instance.
    weak open var delegate: SocketDelegate?

    /// Every delegate method should be called on this dispatch queue. And every method call and variable access will be called on this queue.
    open var queue: DispatchQueue! {
        didSet {
            socket.queue = queue
        }
    }

    /// The current connection status of the socket.
    open var state: SocketStatus = .established


    // MARK: RawTCPSocketDelegate Protocol Implemention
    /**
     The socket did disconnect.

     - parameter socket: The socket which did disconnect.
     */
    open func didDisconnect(_ socket: RawTCPSocketProtocol) {
        state = .closed
        observer?.signal(.disconnected(self))
        delegate?.didDisconnect(self)
    }

    /**
     The socket did read some data.

     - parameter data:    The data read from the socket.
     - parameter withTag: The tag given when calling the `readData` method.
     - parameter from:    The socket where the data is read from.
     */
    open func didReadData(_ data: Data, withTag tag: Int, from: RawTCPSocketProtocol) {
        observer?.signal(.readData(data, tag: tag, on: self))
    }

    /**
     The socket did send some data.

     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter withTag: The tag given when calling the `writeData` method.
     - parameter from:    The socket where the data is sent out.
     */
    open func didWriteData(_ data: Data?, withTag tag: Int, from: RawTCPSocketProtocol) {
        observer?.signal(.wroteData(data, tag: tag, on: self))
    }

    /**
     The socket did connect to remote.

     - note: This never happens for `ProxySocket`.

     - parameter socket: The connected socket.
     */
    open func didConnect(_ socket: RawTCPSocketProtocol) {

    }


}
