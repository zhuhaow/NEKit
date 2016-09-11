import Foundation

public protocol DNSResolverProtocol: class {
    weak var delegate: DNSResolverDelegate? { get set }
    func resolve(session: DNSSession)
    func stop()
}

public protocol DNSResolverDelegate: class {
    func didReceiveResponse(rawResponse: NSData)
}

public class UDPDNSResolver: DNSResolverProtocol, NWUDPSocketDelegate {
    let socket: NWUDPSocket
    public weak var delegate: DNSResolverDelegate?

    public init(address: IPv4Address, port: Port) {
        socket = NWUDPSocket(host: address.presentation, port: Int(port.value))!
        socket.delegate = self
    }

    public func resolve(session: DNSSession) {
        socket.writeData(session.requestMessage.payload)
    }

    public func stop() {
        socket.disconnect()
    }

    public func didReceiveData(data: NSData, from: NWUDPSocket) {
        delegate?.didReceiveResponse(data)
    }
}
