import Foundation

/// Factory building server adapter which requires authentication.
open class HTTPAuthenticationAdapterFactory: ServerAdapterFactory {
    let auth: HTTPAuthentication?

    required public init(serverHost: String, serverPort: Int, auth: HTTPAuthentication?) {
        self.auth = auth
        super.init(serverHost: serverHost, serverPort: serverPort)
    }
}
