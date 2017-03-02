import Foundation
import CommonCrypto

/// This adapter connects to remote through Shadowsocks proxy.
public class ShadowsocksAdapter: AdapterSocket {
    enum ShadowsocksAdapterStatus {
        case invalid,
        connecting,
        connected,
        forwarding,
        stopped
    }

    enum EncryptMethod: String {
        case AES128CFB = "AES-128-CFB", AES192CFB = "AES-192-CFB", AES256CFB = "AES-256-CFB"

        static let allValues: [EncryptMethod] = [.AES128CFB, .AES192CFB, .AES256CFB]
    }

    public let host: String
    public let port: Int

    var internalStatus: ShadowsocksAdapterStatus = .invalid

    private let protocolObfuscater: ProtocolObfuscater.ProtocolObfuscaterBase
    private let cryptor: CryptoStreamProcessor
    private let streamObfuscator: StreamObfuscater.StreamObfuscaterBase

    public init(host: String, port: Int, protocolObfuscater: ProtocolObfuscater.ProtocolObfuscaterBase, cryptor: CryptoStreamProcessor, streamObfuscator: StreamObfuscater.StreamObfuscaterBase) {
        self.host = host
        self.port = port
        self.protocolObfuscater = protocolObfuscater
        self.cryptor = cryptor
        self.streamObfuscator = streamObfuscator

        super.init()

        protocolObfuscater.inputStreamProcessor = cryptor
        protocolObfuscater.outputStreamProcessor = self

        cryptor.inputStreamProcessor = streamObfuscator
        cryptor.outputStreamProcessor = protocolObfuscater

        streamObfuscator.inputStreamProcessor = self
        streamObfuscator.outputStreamProcessor = cryptor
    }

    override public func openSocketWith(session: ConnectSession) {
        super.openSocketWith(session: session)

        do {
            internalStatus = .connecting
            try socket.connectTo(host: host, port: port, enableTLS: false, tlsSettings: nil)
        } catch let error {
            observer?.signal(.errorOccured(error, on: self))
            disconnect()
        }
    }

    override public func didConnectWith(socket: RawTCPSocketProtocol) {
        super.didConnectWith(socket: socket)

        internalStatus = .connected

        protocolObfuscater.start()
    }

    override public func didRead(data: Data, from socket: RawTCPSocketProtocol) {
        super.didRead(data: data, from: socket)

        do {
            try protocolObfuscater.input(data: data)
        } catch {
            disconnect()
        }
    }

    public override func write(data: Data) {
        streamObfuscator.output(data: data)
    }

    public func write(rawData: Data) {
        super.write(data: rawData)
    }

    public func input(data: Data) {
        delegate?.didRead(data: data, from: self)
    }

    public func output(data: Data) {
        write(rawData: data)
    }

    override public func didWrite(data: Data?, by socket: RawTCPSocketProtocol) {
        super.didWrite(data: data, by: socket)

        protocolObfuscater.didWrite()

        switch internalStatus {
        case .forwarding:
            delegate?.didWrite(data: data, by: self)
        default:
            return
        }
    }

    func becomeReadyToForward() {
        internalStatus = .forwarding
        observer?.signal(.readyForForward(self))
        delegate?.didBecomeReadyToForwardWith(socket: self)
    }
}
