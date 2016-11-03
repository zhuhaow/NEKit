import Foundation

public enum ProxySocketEvent: EventType {
    public var description: String {
        switch self {
        case .socketOpened(let socket):
            return "Start processing data from proxy socket \(socket)."
        case .disconnectCalled(let socket):
            return "Disconnect is just called on proxy socket \(socket)."
        case .forceDisconnectCalled(let socket):
            return "Force disconnect is just called on proxy socket \(socket)."
        case .disconnected(let socket):
            return "Proxy socket \(socket) disconnected."
        case let .receivedRequest(request, on: socket):
            return "Proxy socket \(socket) received request \(request)."
        case let .readData(data, tag: tag, on: socket):
            return "Received \(data.count) bytes data with tag \(tag) on proxy socket \(socket)."
        case let .wroteData(data, tag: tag, on: socket):
            if let data = data {
                return "Sent \(data.count) bytes data with tag \(tag) on proxy socket \(socket)."
            } else {
                return "Sent data with tag \(tag) on proxy socket \(socket)."
            }
        case let .receivedResponse(response, on: socket):
            return "Proxy socket \(socket) received response \(response)."
        case .readyForForward(let socket):
            return "Proxy socket \(socket) is ready to forward data."
        case let .errorOccured(error, on: socket):
            return "Proxy socket \(socket) encountered an error \(error)."
        }
    }

    case socketOpened(ProxySocket),
    disconnectCalled(ProxySocket),
    forceDisconnectCalled(ProxySocket),
    disconnected(ProxySocket),
    receivedRequest(ConnectRequest, on: ProxySocket),
    readData(Data, tag: Int, on: ProxySocket),
    wroteData(Data?, tag: Int, on: ProxySocket),
    receivedResponse(ConnectResponse, on: ProxySocket),
    readyForForward(ProxySocket),
    errorOccured(Error, on: ProxySocket)
}
