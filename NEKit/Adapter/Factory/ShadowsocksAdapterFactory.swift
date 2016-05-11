import Foundation

class ShadowsocksAdapterFactory: ServerAdapterFactory {
    typealias EncryptMethod = ShadowsocksAdapter.EncryptMethod
    let encryptMethod: EncryptMethod
    let password: String
    
    init(host: String, port: Int, encryptMethod: EncryptMethod, password: String) {
        self.encryptMethod = encryptMethod
        self.password = password
        super.init(host: host, port: port)
    }
    
    convenience init?(host: String, port: Int, encryptMethod: String, password: String) {
        guard let encryptMethod = EncryptMethod(rawValue: encryptMethod) else {
            return nil
        }
        
        self.init(host: host, port: port, encryptMethod: encryptMethod, password: password)
    }
    
    override func getAdapter(request: ConnectRequest) -> AdapterSocket {
        let adapter = ShadowsocksAdapter(host: serverHost, port: serverPort, encryptMethod: encryptMethod, password: password)
        adapter.socket = RawSocketFactory.getRawSocket()
        return adapter
    }
}