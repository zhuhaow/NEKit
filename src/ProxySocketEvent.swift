import Foundation

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
