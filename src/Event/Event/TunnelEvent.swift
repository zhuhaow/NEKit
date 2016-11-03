import Foundation

public enum TunnelEvent: EventType {
    public var description: String {
        switch self {
        case .opened(let tunnel):
            return "Tunnel \(tunnel) starts processing data."
        case .closeCalled(let tunnel):
            return "Close is called on tunnel \(tunnel)."
        case .forceCloseCalled(let tunnel):
            return "Force close is called on tunnel \(tunnel)."
        case let .receivedRequest(request, from: socket, on: tunnel):
            return "Tunnel \(tunnel) received request \(request) from proxy socket \(socket)."
        case let .receivedReadySignal(socket, currentReady: signal, on: tunnel):
            if signal == 1 {
                return "Tunnel \(tunnel) received ready-for-forward signal from socket \(socket)."
            } else {
                return "Tunnel \(tunnel) received ready-for-forward signal from socket \(socket). Start forwarding data."
            }
        case let .proxySocketReadData(data, tag: tag, from: socket, on: tunnel):
            return "Tunnel \(tunnel) received \(data.count) bytes from proxy socket \(socket) with tag \(tag)."
        case let .proxySocketWroteData(data, tag: tag, from: socket, on: tunnel):
            if let data = data {
                return "Proxy socket \(socket) sent \(data.count) bytes data with tag \(tag) from Tunnel \(tunnel)."
            } else {
                return "Proxy socket \(socket) sent data with tag \(tag) from Tunnel \(tunnel)."
            }
        case let .adapterSocketReadData(data, tag: tag, from: socket, on: tunnel):
            return "Tunnel \(tunnel) received \(data.count) bytes from adapter socket \(socket) with tag \(tag)."
        case let .adapterSocketWroteData(data, tag: tag, from: socket, on: tunnel):
            if let data = data {
                return "Adatper socket \(socket) sent \(data.count) bytes data with tag \(tag) from Tunnel \(tunnel)."
            } else {
                return "Adapter socket \(socket) sent data with tag \(tag) from Tunnel \(tunnel)."
            }
        case let .connectedToRemote(socket, withResponse: response, on: tunnel):
            return "Adapter socket \(socket) connected to remote successfully with response \(response) on tunnel \(tunnel)."
        case let .updatingAdapterSocket(from: old, to: new, on: tunnel):
            return "Updating adapter socket of tunnel \(tunnel) from \(old) to \(new)."
        case .closed(let tunnel):
            return "Tunnel \(tunnel) closed."
        }
    }

    case opened(Tunnel),
    closeCalled(Tunnel),
    forceCloseCalled(Tunnel),
    receivedRequest(ConnectRequest, from: ProxySocket, on: Tunnel),
    receivedReadySignal(SocketProtocol, currentReady: Int, on: Tunnel),
    proxySocketReadData(Data, tag: Int, from: ProxySocket, on: Tunnel),
    proxySocketWroteData(Data?, tag: Int, from: ProxySocket, on: Tunnel),
    adapterSocketReadData(Data, tag: Int, from: AdapterSocket, on: Tunnel),
    adapterSocketWroteData(Data?, tag: Int, from: AdapterSocket, on: Tunnel),
    connectedToRemote(AdapterSocket, withResponse: ConnectResponse, on: Tunnel),
    updatingAdapterSocket(from: AdapterSocket, to: AdapterSocket, on: Tunnel),
    closed(Tunnel)
}
