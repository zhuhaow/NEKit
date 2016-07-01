import Foundation

/// This adapter connects to remote host through a HTTP proxy with SSL.
class SecureHTTPAdapter: HTTPAdapter {
    override init(serverHost: String, serverPort: Int, auth: HTTPAuthentication?) {
        super.init(serverHost: serverHost, serverPort: serverPort, auth: auth)
        secured = true
    }
}
