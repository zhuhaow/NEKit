import Foundation

/// Factory building HTTP adapter.
open class HTTPAdapterFactory: HTTPAuthenticationAdapterFactory {
    required public init(serverHost: String, serverPort: Int, auth: HTTPAuthentication?) {
        super.init(serverHost: serverHost, serverPort: serverPort, auth: auth)
    }

    /**
     Get a HTTP adapter.

     - parameter session: The connect session.

     - returns: The built adapter.
     */
    override open func getAdapterFor(session: ConnectSession) -> AdapterSocket {
        let adapter = HTTPAdapter(serverHost: serverHost, serverPort: serverPort, auth: auth)
        adapter.socket = RawSocketFactory.getRawSocket()
        return adapter
    }
}
