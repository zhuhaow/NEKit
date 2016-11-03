import Foundation

open class AdapterSocket: NSObject, SocketProtocol, RawTCPSocketDelegate {
    open var request: ConnectRequest!
    open var response: ConnectResponse = ConnectResponse()

    open var observer: Observer<AdapterSocketEvent>?

    open let type: String

    open override var description: String {
        return "<\(type) host:\(request.host) port:\(request.port))>"
    }

    /**
     Connect to remote according to the `ConnectRequest`.

     - parameter request: The connect request.
     */
    func openSocketWithRequest(_ request: ConnectRequest) {
        self.request = request
        observer?.signal(.socketOpened(self, withRequest: request))

        socket?.delegate = self
        socket?.queue = queue
        state = .connecting
    }

    // MARK: SocketProtocol Implemention

    /// The underlying TCP socket transmitting data.
    open var socket: RawTCPSocketProtocol!

    /// The delegate instance.
    weak open var delegate: SocketDelegate?

    /// Every delegate method should be called on this dispatch queue. And every method call and variable access will be called on this queue.
    open var queue: DispatchQueue! {
        didSet {
            socket?.queue = queue
        }
    }

    /// The current connection status of the socket.
    open var state: SocketStatus = .invalid

    /// If the socket is disconnected.
    open var isDisconnected: Bool {
        return state == .closed || state == .invalid
    }

    override public init() {
        type = "\(type(of: self))"
        super.init()

        observer = ObserverFactory.currentFactory?.getObserverForAdapterSocket(self)
    }

    /**
     Read data from the socket.

     - parameter tag: The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    open func readDataWithTag(_ tag: Int) {
        socket?.readDataWithTag(tag)
    }

    /**
     Send data to remote.

     - parameter data: Data to send.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    open func writeData(_ data: Data, withTag tag: Int) {
        socket?.writeData(data, withTag: tag)
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
        observer?.signal(.disconnectCalled(self))
        socket?.disconnect()
    }

    /**
     Disconnect the socket immediately.
     */
    open func forceDisconnect() {
        state = .disconnecting
        observer?.signal(.forceDisconnectCalled(self))
        socket?.forceDisconnect()
    }

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

     - parameter socket: The connected socket.
     */
    open func didConnect(_ socket: RawTCPSocketProtocol) {
        state = .established
        observer?.signal(.connected(self, withResponse: response))
        delegate?.didConnect(self, withResponse: response)
    }
}
