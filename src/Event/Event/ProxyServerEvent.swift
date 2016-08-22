import Foundation

public enum ProxyServerEvent: EventType {
    public var description: String {
        switch self {
        case let .NewSocketAccepted(socket, onServer: server):
            return "Proxy server \(server) just accepted a new socket \(socket)."
        case let .TunnelClosed(tunnel, onServer: server):
            return "A tunnel \(tunnel) on proxy server \(server) just closed."
        case .Started(let server):
            return "Proxy server \(server) started."
        case .Stopped(let server):
            return "Proxy server \(server) stopped."
        }
    }

    case NewSocketAccepted(ProxySocket, onServer: ProxyServer), TunnelClosed(Tunnel, onServer: ProxyServer), Started(ProxyServer), Stopped(ProxyServer)
}
