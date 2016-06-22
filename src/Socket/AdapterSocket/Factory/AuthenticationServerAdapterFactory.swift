import Foundation

/// Factory building server adapter which requires authentication.
public class AuthenticationAdapterFactory: ServerAdapterFactory {
    let auth: Authentication?

    required public init(host: String, port: Int, auth: Authentication?) {
        self.auth = auth
        super.init(host: host, port: port)
    }
}
