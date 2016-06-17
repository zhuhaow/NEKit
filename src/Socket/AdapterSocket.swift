import Foundation

class AdapterSocket: NSObject, SocketProtocol, RawTCPSocketDelegate {
    var socket: RawTCPSocketProtocol!
    var request: ConnectRequest!
    var response: ConnectResponse = ConnectResponse()
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
    func didDisconnect(socket: RawTCPSocketProtocol) {
        state = .Closed
        delegate?.didDisconnect(self)
    }

    func didReadData(data: NSData, withTag tag: Int, from: RawTCPSocketProtocol) {
        delegate?.didReadData(data, withTag: tag, from: self)
    }

    func didWriteData(data: NSData?, withTag tag: Int, from: RawTCPSocketProtocol) {
        delegate?.didWriteData(data, withTag: tag, from: self)
    }

    func didConnect(socket: RawTCPSocketProtocol) {
        state = .Established
        delegate?.didConnect(self, withResponse: response)
    }
}
