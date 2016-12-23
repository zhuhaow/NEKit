import Foundation

public protocol DNSResolverProtocol: class {
    weak var delegate: DNSResolverDelegate? { get set }
    func resolve(_ session: DNSSession)
    func stop()
}

public protocol DNSResolverDelegate: class {
    func didReceiveResponse(_ rawResponse: Data)
}

open class UDPDNSResolver: DNSResolverProtocol, NWUDPSocketDelegate {
    let socket: NWUDPSocket
    open weak var delegate: DNSResolverDelegate?

    public init(address: IPAddress, port: Port) {
        socket = NWUDPSocket(host: address.presentation, port: Int(port.value))!
        socket.delegate = self
    }

    open func resolve(_ session: DNSSession) {
        socket.writeData(session.requestMessage.payload)
    }

    open func stop() {
        socket.disconnect()
    }

    open func didReceiveData(_ data: Data, from: NWUDPSocket) {
        delegate?.didReceiveResponse(data)
    }
}
