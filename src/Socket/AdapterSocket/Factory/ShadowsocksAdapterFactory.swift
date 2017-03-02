import Foundation

/// Factory building Shadowsocks adapter.
open class ShadowsocksAdapterFactory: ServerAdapterFactory {
    let protocolObfuscaterFactory: ShadowsocksAdapter.ProtocolObfuscater.Factory
    let cryptorFactory: ShadowsocksAdapter.CryptoStreamProcessor.Factory
    let streamObfuscaterFactory: ShadowsocksAdapter.StreamObfuscater.Factory

    public init(serverHost: String, serverPort: Int, protocolObfuscaterFactory: ShadowsocksAdapter.ProtocolObfuscater.Factory, cryptorFactory: ShadowsocksAdapter.CryptoStreamProcessor.Factory, streamObfuscaterFactory: ShadowsocksAdapter.StreamObfuscater.Factory) {
        self.protocolObfuscaterFactory = protocolObfuscaterFactory
        self.cryptorFactory = cryptorFactory
        self.streamObfuscaterFactory = streamObfuscaterFactory
        super.init(serverHost: serverHost, serverPort: serverPort)
    }

    /**
     Get a Shadowsocks adapter.

     - parameter session: The connect session.

     - returns: The built adapter.
     */
    override open func getAdapterFor(session: ConnectSession) -> AdapterSocket {
        let adapter = ShadowsocksAdapter(host: serverHost, port: serverPort, protocolObfuscater: protocolObfuscaterFactory.build(), cryptor: cryptorFactory.build(), streamObfuscator: streamObfuscaterFactory.build(for: session))
        adapter.socket = RawSocketFactory.getRawSocket()
        return adapter
    }
}
