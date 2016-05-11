import Foundation

class ServerAdapterFactory: AdapterFactoryProtocol {
    let serverHost: String
    let serverPort: Int

    init(host: String, port: Int) {
        serverHost = host
        serverPort = port
    }

    func canHandle(request: ConnectRequest) -> Bool {
        return false
    }

    func getAdapter(request: ConnectRequest) -> AdapterSocket {
        return getDirectAdapter()
    }
}
