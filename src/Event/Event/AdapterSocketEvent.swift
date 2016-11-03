import Foundation

public enum AdapterSocketEvent: EventType {
    public var description: String {
        switch self {
        case let .socketOpened(socket, withRequest: request):
            return "Adatper socket \(socket) starts to connect to remote with request \(request)."
        case .disconnectCalled(let socket):
            return "Disconnect is just called on adapter socket \(socket)."
        case .forceDisconnectCalled(let socket):
            return "Force disconnect is just called on adapter socket \(socket)."
        case .disconnected(let socket):
            return "Adapter socket \(socket) disconnected."
        case let .readData(data, tag: tag, on: socket):
            return "Received \(data.count) bytes data with tag \(tag) on adatper socket \(socket)."
        case let .wroteData(data, tag: tag, on: socket):
            if let data = data {
                return "Sent \(data.count) bytes data with tag \(tag) on adapter socket \(socket)."
            } else {
                return "Sent data with tag \(tag) on adapter socket \(socket)."
            }
        case let .connected(socket, withResponse: response):
            return "Adapter socket \(socket) connected to remote with response \(response)."
        case .readyForForward(let socket):
            return "Adatper socket \(socket) is ready to forward data."
        case let .errorOccured(error, on: socket):
            return "Adapter socket \(socket) encountered an error \(error)."
        }
    }

    case socketOpened(AdapterSocket, withRequest: ConnectRequest),
    disconnectCalled(AdapterSocket),
    forceDisconnectCalled(AdapterSocket),
    disconnected(AdapterSocket),
    readData(Data, tag: Int, on: AdapterSocket),
    wroteData(Data?, tag: Int, on: AdapterSocket),
    connected(AdapterSocket, withResponse: ConnectResponse),
    readyForForward(AdapterSocket),
    errorOccured(Error, on: AdapterSocket)
}
