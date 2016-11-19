import Foundation

/// Factory building Shadowsocks adapter.
open class ShadowsocksAdapterFactory: ServerAdapterFactory {
    let encryptAlgorithm: CryptoAlgorithm
    let password: String
    let streamObfuscaterType: ShadowsocksStreamObfuscater.Type

    public init(serverHost: String, serverPort: Int, encryptAlgorithm: CryptoAlgorithm, password: String, streamObfuscaterType: ShadowsocksStreamObfuscater.Type = ShadowsocksAdapter.OriginStreamObfuscater.self) {
        self.encryptAlgorithm = encryptAlgorithm
        self.password = password
        self.streamObfuscaterType = streamObfuscaterType
        super.init(serverHost: serverHost, serverPort: serverPort)
    }

    public convenience init?(serverHost: String, serverPort: Int, encryptAlgorithm: String, password: String, streamObfuscaterType: ShadowsocksStreamObfuscater.Type = ShadowsocksAdapter.OriginStreamObfuscater.self) {
        guard let encryptAlgorithm = CryptoAlgorithm(rawValue: encryptAlgorithm.uppercased()) else {
            return nil
        }

        self.init(serverHost: serverHost, serverPort: serverPort, encryptAlgorithm: encryptAlgorithm, password: password, streamObfuscaterType: streamObfuscaterType)
    }

    /**
     Get a Shadowsocks adapter.

     - parameter request: The connect request.

     - returns: The built adapter.
     */
    override func getAdapter(_ request: ConnectRequest) -> AdapterSocket {
        let adapter = ShadowsocksAdapter(host: serverHost, port: serverPort, encryptAlgorithm: encryptAlgorithm, password: password, streamObfuscaterType: streamObfuscaterType)
        adapter.socket = RawSocketFactory.getRawSocket()
        return adapter
    }
}
