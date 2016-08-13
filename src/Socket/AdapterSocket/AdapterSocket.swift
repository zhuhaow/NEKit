import Foundation

class AdapterSocket: NSObject, SocketProtocol, RawTCPSocketDelegate {
    var request: ConnectRequest!
    var response: ConnectResponse = ConnectResponse()

    /**
     Connect to remote according to the `ConnectRequest`.

     - parameter request: The connect request.
     */
    func openSocketWithRequest(request: ConnectRequest) {
        self.request = request
        socket.delegate = self
        socket.queue = queue
        state = .Connecting
    }

    // MARK: SocketProtocol Implemention

    /// The underlying TCP socket transmitting data.
    var socket: RawTCPSocketProtocol!

    /// The delegate instance.
    weak var delegate: SocketDelegate?

    /// Every delegate method should be called on this dispatch queue. And every method call and variable access will be called on this queue.
    var queue: dispatch_queue_t! {
        didSet {
            socket?.queue = queue
        }
    }

    /// The current connection status of the socket.
    var state: SocketStatus = .Invalid

    /// If the socket is disconnected.
    var isDisconnected: Bool {
        return state == .Closed || state == .Invalid
    }
    
    /**
     Read data from the socket.
     
     - parameter tag: The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    func readDataWithTag(tag: Int) {
        socket.readDataWithTag(tag)
    }
    
    /**
     Send data to remote.
     
     - parameter data: Data to send.
     - parameter tag:  The tag identifying the data in the callback delegate method.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    func writeData(data: NSData, withTag tag: Int) {
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

     - parameter socket: The connected socket.
     */
    func didConnect(socket: RawTCPSocketProtocol) {
        state = .Established
        delegate?.didConnect(self, withResponse: response)
    }
}
