import Foundation

public protocol EventType: CustomStringConvertible {}

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

public enum ProxySocketEvent: EventType {
    public var description: String {
        switch self {
        case .SocketOpened(let socket):
            return "Start processing data from proxy socket \(socket)."
        case .DisconnectCalled(let socket):
            return "Disconnect is just called on proxy socket \(socket)."
        case .ForceDisconnectCalled(let socket):
            return "Force disconnect is just called on proxy socket \(socket)."
        case .Disconnected(let socket):
            return "Proxy socket \(socket) disconnected."
        case let .ReceivedRequest(request, on: socket):
            return "Proxy socket \(socket) received request \(request)."
        case let .ReadData(data, tag: tag, on: socket):
            return "Received \(data.length) bytes data with tag \(tag) on proxy socket \(socket)."
        case let .WroteData(data, tag: tag, on: socket):
            if let data = data {
                return "Sent \(data.length) bytes data with tag \(tag) on proxy socket \(socket)."
            } else {
                return "Sent data with tag \(tag) on proxy socket \(socket)."
            }
        case let .ReceivedResponse(response, on: socket):
            return "Proxy socket \(socket) received response \(response)."
        case .ReadyForForward(let socket):
            return "Proxy socket \(socket) is ready to forward data."
        case let .ErrorOccured(error, on: socket):
            return "Proxy socket \(socket) encountered an error \(error)."
        }
    }

    case SocketOpened(ProxySocket),
    DisconnectCalled(ProxySocket),
    ForceDisconnectCalled(ProxySocket),
    Disconnected(ProxySocket),
    ReceivedRequest(ConnectRequest, on: ProxySocket),
    ReadData(NSData, tag: Int, on: ProxySocket),
    WroteData(NSData?, tag: Int, on: ProxySocket),
    ReceivedResponse(ConnectResponse, on: ProxySocket),
    ReadyForForward(ProxySocket),
    ErrorOccured(ErrorType, on: ProxySocket)
}


public enum AdapterSocketEvent: EventType {
    public var description: String {
        switch self {
        case let .SocketOpened(socket, withRequest: request):
            return "Adatper socket \(socket) starts to connect to remote with request \(request)."
        case .DisconnectCalled(let socket):
            return "Disconnect is just called on adapter socket \(socket)."
        case .ForceDisconnectCalled(let socket):
            return "Force disconnect is just called on adapter socket \(socket)."
        case .Disconnected(let socket):
            return "Adapter socket \(socket) disconnected."
        case let .ReadData(data, tag: tag, on: socket):
            return "Received \(data.length) bytes data with tag \(tag) on adatper socket \(socket)."
        case let .WroteData(data, tag: tag, on: socket):
            if let data = data {
                return "Sent \(data.length) bytes data with tag \(tag) on adapter socket \(socket)."
            } else {
                return "Sent data with tag \(tag) on adapter socket \(socket)."
            }
        case let .Connected(socket, withResponse: response):
            return "Adapter socket \(socket) connected to remote with response \(response)."
        case .ReadyForForward(let socket):
            return "Adatper socket \(socket) is ready to forward data."
        case let .ErrorOccured(error, on: socket):
            return "Adapter socket \(socket) encountered an error \(error)."
        }
    }

    case SocketOpened(AdapterSocket, withRequest: ConnectRequest),
    DisconnectCalled(AdapterSocket),
    ForceDisconnectCalled(AdapterSocket),
    Disconnected(AdapterSocket),
    ReadData(NSData, tag: Int, on: AdapterSocket),
    WroteData(NSData?, tag: Int, on: AdapterSocket),
    Connected(AdapterSocket, withResponse: ConnectResponse),
    ReadyForForward(AdapterSocket),
    ErrorOccured(ErrorType, on: AdapterSocket)
}

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
