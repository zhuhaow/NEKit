import Foundation

/// Factory building adapter with proxy server host and port.
open class ServerAdapterFactory: AdapterFactory {
    let serverHost: String
    let serverPort: Int

    public init(serverHost: String, serverPort: Int) {
        self.serverHost = serverHost
        self.serverPort = serverPort
    }
}
