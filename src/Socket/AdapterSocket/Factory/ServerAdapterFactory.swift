import Foundation

/// Factory building adapter with proxy server host and port.
public class ServerAdapterFactory: AdapterFactory {
    let serverHost: String
    let serverPort: Int

    init(serverHost: String, serverPort: Int) {
        self.serverHost = serverHost
        self.serverPort = serverPort
    }
}
