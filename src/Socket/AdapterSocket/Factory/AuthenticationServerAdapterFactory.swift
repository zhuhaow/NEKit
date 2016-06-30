import Foundation

/// Factory building server adapter which requires authentication.
public class AuthenticationAdapterFactory: ServerAdapterFactory {
    let auth: Authentication?

    required public init(serverHost: String, serverPort: Int, auth: Authentication?) {
        self.auth = auth
        super.init(serverHost: serverHost, serverPort: serverPort)
    }
}
