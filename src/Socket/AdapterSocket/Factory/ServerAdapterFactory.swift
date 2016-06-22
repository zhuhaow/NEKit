import Foundation

/// Factory building adapter with server host and port.
public class ServerAdapterFactory: AdapterFactory {
    let serverHost: String
    let serverPort: Int

    init(host: String, port: Int) {
        serverHost = host
        serverPort = port
    }
}
