import Foundation

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
