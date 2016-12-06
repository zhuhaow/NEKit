import Foundation
import CommonCrypto

/// This adapter connects to remote through Shadowsocks proxy.
public class ShadowsocksAdapter: AdapterSocket {
    enum ShadowsocksAdapterStatus {
        case invalid,
        connecting,
        waitingIV,
        readingIV,
        forwarding,
        stopped
    }

    enum EncryptMethod: String {
        case AES128CFB = "AES-128-CFB", AES192CFB = "AES-192-CFB", AES256CFB = "AES-256-CFB"

        static let allValues: [EncryptMethod] = [.AES128CFB, .AES192CFB, .AES256CFB]
    }

    var readIV: Data!
    let key: Data
    public let encryptAlgorithm: CryptoAlgorithm
    public let host: String
    public let port: Int

    let streamObfuscaterType: ShadowsocksStreamObfuscater.Type

    var readingIV: Bool = false
    var nextReadTag: Int = 0

    var internalStatus: ShadowsocksAdapterStatus = .invalid

    lazy var writeIV: Data = {
        [unowned self] in
        CryptoHelper.getIV(self.encryptAlgorithm)
        }()
    lazy var ivLength: Int = {
        [unowned self] in
        CryptoHelper.getIVLength(self.encryptAlgorithm)
        }()
    lazy var encryptor: StreamCryptoProtocol = {
        [unowned self] in
        self.getCrypto(.encrypt)
        }()
    lazy var decryptor: StreamCryptoProtocol = {
        [unowned self] in
        self.getCrypto(.decrypt)
        }()
    lazy var streamObfuscater: ShadowsocksStreamObfuscater = {
        [unowned self] in
        return self.streamObfuscaterType.init(key: self.key, iv: self.writeIV)
    }()

    public init(host: String, port: Int, encryptAlgorithm: CryptoAlgorithm, password: String, streamObfuscaterType: ShadowsocksStreamObfuscater.Type = OriginStreamObfuscater.self) {
        self.encryptAlgorithm = encryptAlgorithm
        self.key = CryptoHelper.getKey(password, methodType: encryptAlgorithm)
        self.host = host
        self.port = port
        self.streamObfuscaterType = streamObfuscaterType

        super.init()
    }

    override func openSocketWith(request: ConnectRequest) {
        super.openSocketWith(request: request)

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

        var helloData = writeIV
        var requestData = streamObfuscater.requestData(for: request)
        encryptData(&requestData)
        helloData.append(requestData)

        internalStatus = .waitingIV
        write(rawData: helloData)
    }

    func write(rawData: Data) {
        super.write(data: rawData)
    }

    override public func readData() {
        switch internalStatus {
        case .forwarding:
            super.readData()
        case .waitingIV:
            internalStatus = .readingIV
            socket.readDataTo(length: ivLength)
        default:
            return
        }
    }

    override public func write(data: Data) {
        var data = streamObfuscater.output(data: data)

        encryptData(&data)
        write(rawData: data)
    }

    override public func didRead(data: Data, from socket: RawTCPSocketProtocol) {
        super.didRead(data: data, from: socket)

        switch internalStatus {
        case .forwarding:
            var data = streamObfuscater.input(data: data)
            decryptData(&data)
            delegate?.didRead(data: data, from: self)
        case .readingIV:
            // IV is only read when the first read is requested
            readIV = data
            internalStatus = .forwarding
            readData()
        default:
            return
        }
    }

    override public func didWrite(data: Data?, by socket: RawTCPSocketProtocol) {
        super.didWrite(data: data, by: socket)

        switch internalStatus {
        case .forwarding:
            delegate?.didWrite(data: data, by: self)
        case .waitingIV:
            observer?.signal(.readyForForward(self))
            delegate?.didBecomeReadyToForwardWith(socket: self)
        default:
            return
        }
    }

    func encryptData(_ data: inout Data) {
        return encryptor.update(&data)
    }

    func decryptData(_ data: inout Data) {
        return decryptor.update(&data)
    }

    fileprivate func getCrypto(_ operation: CryptoOperation) -> StreamCryptoProtocol {
        switch encryptAlgorithm {
        case .AES128CFB, .AES192CFB, .AES256CFB:
            switch operation {
            case .decrypt:
                return CCCrypto(operation: .decrypt, mode: .cfb, algorithm: .aes, initialVector: readIV, key: key)
            case .encrypt:
                return CCCrypto(operation: .encrypt, mode: .cfb, algorithm: .aes, initialVector: writeIV, key: key)
            }
        case .CHACHA20:
            switch operation {
            case .decrypt:
                return SodiumStreamCrypto(key: key, iv: readIV, algorithm: .chacha20)
            case .encrypt:
                return SodiumStreamCrypto(key: key, iv: writeIV, algorithm: .chacha20)
            }
        case .SALSA20:
            switch operation {
            case .decrypt:
                return SodiumStreamCrypto(key: key, iv: readIV, algorithm: .salsa20)
            case .encrypt:
                return SodiumStreamCrypto(key: key, iv: writeIV, algorithm: .salsa20)
            }
        case .RC4MD5:
            var combinedKey = Data(capacity: key.count + ivLength)
            combinedKey.append(key)
            switch operation {
            case .decrypt:
                combinedKey.append(readIV)
                return CCCrypto(operation: .decrypt, mode: .rc4, algorithm: .rc4, initialVector: nil, key: MD5Hash.final(combinedKey))
            case .encrypt:
                combinedKey.append(writeIV)
                return CCCrypto(operation: .encrypt, mode: .rc4, algorithm: .rc4, initialVector: nil, key: MD5Hash.final(combinedKey))
            }
        }
    }
}
