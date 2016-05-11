import Foundation

class SecureHTTPAdapter: HTTPAdapter {
    override init(serverHost: String, serverPort: Int, auth: Authentication?) {
        super.init(serverHost: serverHost, serverPort: serverPort, auth: auth)
        secured = false
    }
}
