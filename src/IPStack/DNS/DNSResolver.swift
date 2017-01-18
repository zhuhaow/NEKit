import Foundation

@objc public protocol DNSResolverProtocol: class, NSObjectProtocol {
    weak var delegate: DNSResolverDelegate? { get set }
    func resolve(session: DNSSession)
    func stop()
}

@objc public protocol DNSResolverDelegate: class, NSObjectProtocol {
    func didReceive(rawResponse: Data)
}

@objc public class UDPDNSResolver: NSObject, DNSResolverProtocol, NWUDPSocketDelegate {
    let socket: NWUDPSocket
    public weak var delegate: DNSResolverDelegate?

    public init(address: IPAddress, port: Port) {
        socket = NWUDPSocket(host: address.presentation, port: Int(port.value))!
        super.init()
        socket.delegate = self
    }

    public func resolve(session: DNSSession) {
        socket.write(data: session.requestMessage.payload)
    }

    public func stop() {
        socket.disconnect()
    }

    public func didReceive(data: Data, from: NWUDPSocket) {
        delegate?.didReceive(rawResponse: data)
    }
    
    public func didCancel(socket: NWUDPSocket) {
        
    }
}
