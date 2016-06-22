import Foundation

/// Factory building adapter with server host and port.
class ServerAdapterFactory: AdapterFactoryProtocol {
    let serverHost: String
    let serverPort: Int

    init(host: String, port: Int) {
        serverHost = host
        serverPort = port
    }

    func getAdapter(request: ConnectRequest) -> AdapterSocket {
        return getDirectAdapter()
    }
}
