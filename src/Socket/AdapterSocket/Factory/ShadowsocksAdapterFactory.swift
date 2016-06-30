import Foundation

/// Factory building Shadowsocks adapter.
public class ShadowsocksAdapterFactory: ServerAdapterFactory {
    typealias EncryptMethod = ShadowsocksAdapter.EncryptMethod
    let encryptMethod: EncryptMethod
    let password: String

    init(serverHost: String, serverPort: Int, encryptMethod: EncryptMethod, password: String) {
        self.encryptMethod = encryptMethod
        self.password = password
        super.init(serverHost: serverHost, serverPort: serverPort)
    }

    public convenience init?(serverHost: String, serverPort: Int, encryptMethod: String, password: String) {
        guard let encryptMethod = EncryptMethod(rawValue: encryptMethod) else {
            return nil
        }

        self.init(serverHost: serverHost, serverPort: serverPort, encryptMethod: encryptMethod, password: password)
    }

    /**
     Get a Shadowsocks adapter.

     - parameter request: The connect request.

     - returns: The built adapter.
     */
    override func getAdapter(request: ConnectRequest) -> AdapterSocket {
        let adapter = ShadowsocksAdapter(host: serverHost, port: serverPort, encryptMethod: encryptMethod, password: password)
        adapter.socket = RawSocketFactory.getRawSocket()
        return adapter
    }
}
