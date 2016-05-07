import Foundation

class SecureHTTPAdapterFactory : HTTPAdapterFactory {
    override func getAdapter(request: ConnectRequest) -> AdapterSocket {
        let adapter = SecureHTTPAdapter(serverHost: serverHost, serverPort: serverPort, auth: auth)
        adapter.socket = GCDSocket()
        return adapter
    }
}