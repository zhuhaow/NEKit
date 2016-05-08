import Foundation

class AdapterSocket : NSObject, SocketProtocol, RawSocketDelegate {
    var socket: RawSocketProtocol!
    var request : ConnectRequest!
    weak var delegate: SocketDelegate?
    var delegateQueue: dispatch_queue_t! {
        didSet {
            socket?.delegateQueue = delegateQueue
        }
    }
    
    var state: SocketStatus = .Invalid
    
    func openSocketWithRequest(request: ConnectRequest) {
        self.request = request
        socket.delegate = self
        socket.delegateQueue = delegateQueue
        state = .Connecting
    }
    
    func writeData(data: NSData, withTag tag: Int = 0) {
        socket.writeData(data, withTag: tag)
    }
    
    func readDataWithTag(tag: Int = 0) {
        socket.readDataWithTag(tag)
    }

    // MARK: SocketDelegate protocol implemention
    func didDisconnect(socket: RawSocketProtocol) {
        state = .Closed
        delegate?.didDisconnect(self)
    }
    
    func didReadData(data: NSData, withTag tag: Int, from: RawSocketProtocol) {
        delegate?.didReadData(data, withTag: tag, from: self)
    }
    
    func didWriteData(data: NSData?, withTag tag: Int, from: RawSocketProtocol) {
        delegate?.didWriteData(data, withTag: tag, from: self)
    }
    
    func didConnect(socket: RawSocketProtocol) {
        state = .Established
        let response = ConnectResponse()
        delegate?.didConnect(self, withResponse: response)
    }
}