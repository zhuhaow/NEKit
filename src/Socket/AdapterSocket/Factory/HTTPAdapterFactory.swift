import Foundation

/// Factory building HTTP adapter.
public class HTTPAdapterFactory: HTTPAuthenticationAdapterFactory {
    public override init() {}
    /**
     Get a HTTP adapter.

     - parameter request: The connect request.

     - returns: The built adapter.
     */
    override func getAdapter(request: ConnectRequest) -> AdapterSocket {
        let adapter = HTTPAdapter(serverHost: serverHost, serverPort: serverPort, auth: auth)
        adapter.socket = RawSocketFactory.getRawSocket()
        return adapter
    }
}
