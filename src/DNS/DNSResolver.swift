import Foundation

public protocol DNSResolverProtocol: class {
    weak var delegate: DNSResolverDelegate? { get set }
    func resolve(session: DNSSession)
}

public protocol DNSResolverDelegate: class {
    func didReceiveResponse(rawResponse: NSData)
}

public class UDPDNSResolver: DNSResolverProtocol, NWUDPSocketDelegate {
    let socket: NWUDPSocket
    public weak var delegate: DNSResolverDelegate?

    public init(address: IPv4Address, port: Port) {
        socket = NWUDPSocket(host: address.presentation, port: port.intValue)
        socket.delegate = self
    }

    public func resolve(session: DNSSession) {
        socket.writeData(session.requestMessage.payload)
    }

    func didReceiveData(data: NSData, from: NWUDPSocket) {
        delegate?.didReceiveResponse(data)
    }
}
