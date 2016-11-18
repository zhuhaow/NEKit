import Foundation
import CommonCrypto

/// This adapter connects to remote through Shadowsocks proxy.
open class ShadowsocksAdapter: AdapterSocket {
    var readIV: Data!
    let key: Data
    open let encryptAlgorithm: CryptoAlgorithm
    open let host: String
    open let port: Int

    let streamObfuscaterType: ShadowsocksStreamObfuscater.Type

    var readingIV: Bool = false
    var nextReadTag: Int = 0

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

    enum EncryptMethod: String {
        case AES128CFB = "AES-128-CFB", AES192CFB = "AES-192-CFB", AES256CFB = "AES-256-CFB"

        static let allValues: [EncryptMethod] = [.AES128CFB, .AES192CFB, .AES256CFB]
    }

    enum ShadowsocksTag: Int {
        case initialVector = 25000, connect
    }

    public init(host: String, port: Int, encryptAlgorithm: CryptoAlgorithm, password: String, streamObfuscaterType: ShadowsocksStreamObfuscater.Type = OriginStreamObfuscater.self) {
        self.encryptAlgorithm = encryptAlgorithm
        self.key = CryptoHelper.getKey(password, methodType: encryptAlgorithm)
        self.host = host
        self.port = port
        self.streamObfuscaterType = streamObfuscaterType

        super.init()
    }

    override func openSocketWithRequest(_ request: ConnectRequest) {
        super.openSocketWithRequest(request)

        do {
            try socket.connectTo(host, port: port, enableTLS: false, tlsSettings: nil)
        } catch let error {
            observer?.signal(.errorOccured(error, on: self))
            disconnect()
        }
    }

    override open func didConnect(_ socket: RawTCPSocketProtocol) {
        super.didConnect(socket)

        var helloData = writeIV
        var requestData = streamObfuscater.requestData(for: request)
        encryptData(&requestData)
        helloData.append(requestData)

        writeRawData(helloData, withTag: ShadowsocksTag.connect.rawValue)
    }

    func writeRawData(_ data: Data, withTag tag: Int) {
        super.writeData(data, withTag: tag)
    }

    override open func readDataWithTag(_ tag: Int) {
        if readIV == nil && !readingIV {
            readingIV = true
            nextReadTag = tag
            socket.readDataToLength(ivLength, withTag: ShadowsocksTag.initialVector.rawValue)
        } else {
            super.readDataWithTag(tag)
        }
    }

    override open func writeData(_ data: Data, withTag tag: Int) {
        var data = streamObfuscater.output(data: data)
        
        encryptData(&data)
        writeRawData(data, withTag: tag)
    }

    override open func didReadData(_ data: Data, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didReadData(data, withTag: tag, from: socket)

        if tag == ShadowsocksTag.initialVector.rawValue {
            readIV = data
            readingIV = false
            super.readDataWithTag(nextReadTag)
        } else {
            var data = streamObfuscater.input(data: data)
            decryptData(&data)
            delegate?.didReadData(data, withTag: tag, from: self)
        }
    }

    override open func didWriteData(_ data: Data?, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didWriteData(data, withTag: tag, from: socket)

        if tag == ShadowsocksTag.connect.rawValue {
            observer?.signal(.readyForForward(self))
            delegate?.readyToForward(self)
        } else {
            delegate?.didWriteData(nil, withTag: tag, from: self)
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
