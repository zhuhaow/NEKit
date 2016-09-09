import Foundation

/// Factory building secured HTTP (HTTP with SSL) adapter.
public class SecureHTTPAdapterFactory: HTTPAdapterFactory {
    required public init(serverHost: String, serverPort: Int, auth: HTTPAuthentication?) {
        super.init(serverHost: serverHost, serverPort: serverPort, auth: auth)
    }

    /**
     Get a secured HTTP adapter.

     - parameter request: The connect request.

     - returns: The built adapter.
     */
    override func getAdapter(request: ConnectRequest) -> AdapterSocket {
        let adapter = SecureHTTPAdapter(serverHost: serverHost, serverPort: serverPort, auth: auth)
        adapter.socket = RawSocketFactory.getRawSocket()
        return adapter
    }
}
