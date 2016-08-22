import Foundation

public enum TunnelEvent: EventType {
    public var description: String {
        switch self {
        case .Opened(let tunnel):
            return "Tunnel \(tunnel) starts processing data."
        case .CloseCalled(let tunnel):
            return "Close is called on tunnel \(tunnel)."
        case .ForceCloseCalled(let tunnel):
            return "Force close is called on tunnel \(tunnel)."
        case let .ReceivedRequest(request, from: socket, on: tunnel):
            return "Tunnel \(tunnel) received request \(request) from proxy socket \(socket)."
        case let .ReceivedReadySignal(socket, currentReady: signal, on: tunnel):
            if signal == 1 {
                return "Tunnel \(tunnel) received ready-for-forward signal from socket \(socket)."
            } else {
                return "Tunnel \(tunnel) received ready-for-forward signal from socket \(socket). Start forwarding data."
            }
        case let .ProxySocketReadData(data, tag: tag, from: socket, on: tunnel):
            return "Tunnel \(tunnel) received \(data.length) bytes from proxy socket \(socket) with tag \(tag)."
        case let .ProxySocketWroteData(data, tag: tag, from: socket, on: tunnel):
            if let data = data {
                return "Proxy socket \(socket) sent \(data.length) bytes data with tag \(tag) from Tunnel \(tunnel)."
            } else {
                return "Proxy socket \(socket) sent data with tag \(tag) from Tunnel \(tunnel)."
            }
        case let .AdapterSocketReadData(data, tag: tag, from: socket, on: tunnel):
            return "Tunnel \(tunnel) received \(data.length) bytes from adapter socket \(socket) with tag \(tag)."
        case let .AdapterSocketWroteData(data, tag: tag, from: socket, on: tunnel):
            if let data = data {
                return "Adatper socket \(socket) sent \(data.length) bytes data with tag \(tag) from Tunnel \(tunnel)."
            } else {
                return "Adapter socket \(socket) sent data with tag \(tag) from Tunnel \(tunnel)."
            }
        case let .ConnectedToRemote(socket, withResponse: response, on: tunnel):
            return "Adapter socket \(socket) connected to remote successfully with response \(response) on tunnel \(tunnel)."
        case let .UpdatingAdapterSocket(from: old, to: new, on: tunnel):
            return "Updating adapter socket of tunnel \(tunnel) from \(old) to \(new)."
        case .Closed(let tunnel):
            return "Tunnel \(tunnel) closed."
        }
    }

    case Opened(Tunnel),
    CloseCalled(Tunnel),
    ForceCloseCalled(Tunnel),
    ReceivedRequest(ConnectRequest, from: ProxySocket, on: Tunnel),
    ReceivedReadySignal(SocketProtocol, currentReady: Int, on: Tunnel),
    ProxySocketReadData(NSData, tag: Int, from: ProxySocket, on: Tunnel),
    ProxySocketWroteData(NSData?, tag: Int, from: ProxySocket, on: Tunnel),
    AdapterSocketReadData(NSData, tag: Int, from: AdapterSocket, on: Tunnel),
    AdapterSocketWroteData(NSData?, tag: Int, from: AdapterSocket, on: Tunnel),
    ConnectedToRemote(AdapterSocket, withResponse: ConnectResponse, on: Tunnel),
    UpdatingAdapterSocket(from: AdapterSocket, to: AdapterSocket, on: Tunnel),
    Closed(Tunnel)
}
