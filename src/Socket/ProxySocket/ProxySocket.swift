import Foundation

class ProxySocket: NSObject, SocketProtocol, RawTCPSocketDelegate {
    var socket: RawTCPSocketProtocol!
    weak var delegate: SocketDelegate?
    var delegateQueue: dispatch_queue_t! {
        didSet {
            socket.queue = delegateQueue
        }
    }

    var request: ConnectRequest?

    var state: SocketStatus = .Established

    init(socket: RawTCPSocketProtocol) {
        self.socket = socket
        super.init()
        self.socket.delegate = self
    }

    func openSocket() {
    }

    func respondToResponse(response: ConnectResponse) {

    }

    // MARK: RawTCPSocketDelegate protocol implemention
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

    }
}
