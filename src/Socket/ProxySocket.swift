import Foundation

class ProxySocket: NSObject, ProxySocketProtocol, RawSocketDelegate {
    var socket: RawSocketProtocol!
    weak var delegate: SocketDelegate?
    var delegateQueue: dispatch_queue_t! {
        didSet {
            socket.delegateQueue = delegateQueue
        }
    }

    var request: ConnectRequest?

    var state: SocketStatus = .Established

    init(socket: RawSocketProtocol) {
        self.socket = socket
        super.init()
        self.socket.delegate = self
    }

    func openSocket() {
    }

    func respondToResponse(response: ConnectResponse) {

    }

    // MARK: RawSocketDelegate protocol implemention
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

    }
}
