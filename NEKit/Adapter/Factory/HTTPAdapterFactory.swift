import Foundation

class HTTPAdapterFactory : AuthenticationAdapterFactory {

    override func canHandle(request: ConnectRequest) -> Bool {
        return true
    }
    
    override func getAdapter(request: ConnectRequest) -> AdapterSocket {
        let adapter = HTTPAdapter(serverHost: serverHost, serverPort: serverPort, auth: auth)
        adapter.socket = GCDSocket()
        return adapter
    }
}