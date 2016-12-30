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
        case let .receivedRequest(session, on: socket):
            return "Proxy socket \(socket) received request \(session)."
        case let .readData(data, on: socket):
            return "Received \(data.count) bytes data on proxy socket \(socket)."
        case let .wroteData(data, on: socket):
            if let data = data {
                return "Sent \(data.count) bytes data on proxy socket \(socket)."
            } else {
                return "Sent data on proxy socket \(socket)."
            }
        case let .askedToResponseTo(adapter, on: socket):
            return "Proxy socket \(socket) is asked to respond to adapter \(adapter)."
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
    receivedRequest(ConnectSession, on: ProxySocket),
    readData(Data, on: ProxySocket),
    wroteData(Data?, on: ProxySocket),
    askedToResponseTo(AdapterSocket, on: ProxySocket),
    readyForForward(ProxySocket),
    errorOccured(Error, on: ProxySocket)
}
