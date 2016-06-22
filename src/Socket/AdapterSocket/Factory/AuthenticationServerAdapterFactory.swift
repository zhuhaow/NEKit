import Foundation

/// Factory building server adapter which requires authentication.
class AuthenticationAdapterFactory: ServerAdapterFactory {
    let auth: Authentication?

    required init(host: String, port: Int, auth: Authentication?) {
        self.auth = auth
        super.init(host: host, port: port)
    }
}
