import Foundation
import CommonCrypto

/// This adapter connects to remote through Shadowsocks proxy.
class ShadowsocksAdapter: AdapterSocket {
    var readIV: NSData!
    let key: NSData
    let encryptAlgorithm: CryptoAlgorithm
    let host: String
    let port: Int

    var readingIV: Bool = false
    var nextReadTag: Int = 0

    lazy var writeIV: NSData = {
        [unowned self] in
        CryptoHelper.getIV(self.encryptAlgorithm)
    }()
    lazy var ivLength: Int = {
        [unowned self] in
        CryptoHelper.getIVLength(self.encryptAlgorithm)
    }()
    lazy var encryptor: StreamCryptoProtocol = {
        [unowned self] in
        self.getCrypto(.Encrypt)
    }()
    lazy var decryptor: StreamCryptoProtocol = {
        [unowned self] in
        self.getCrypto(.Decrypt)
    }()

    enum EncryptMethod: String {
        case AES128CFB = "AES-128-CFB", AES192CFB = "AES-192-CFB", AES256CFB = "AES-256-CFB"

        static let allValues: [EncryptMethod] = [.AES128CFB, .AES192CFB, .AES256CFB]
    }

    enum ShadowsocksTag: Int {
        case InitialVector = 25000, Connect
    }

    init(host: String, port: Int, encryptAlgorithm: CryptoAlgorithm, password: String) {
        self.encryptAlgorithm = encryptAlgorithm
        self.key = CryptoHelper.getKey(password, methodType: encryptAlgorithm)
        self.host = host
        self.port = port
        super.init()
    }

    override func openSocketWithRequest(request: ConnectRequest) {
        super.openSocketWithRequest(request)
        do {
            try socket.connectTo(host, port: port, enableTLS: false, tlsSettings: nil)
        } catch {}
    }


    override func didConnect(socket: RawTCPSocketProtocol) {
        super.didConnect(socket)

        let helloData = NSMutableData(data: writeIV)
        if request.isIPv4() {
            var response: [UInt8] = [0x01]
            response += Utils.IP.IPv4ToBytes(request.host)!
            var responseData = NSData(bytes: response, length: response.count)
            responseData = encryptData(responseData)
            helloData.appendData(responseData)
        } else if request.isIPv6() {
            var response: [UInt8] = [0x04]
            response += Utils.IP.IPv6ToBytes(request.host)!
            var responseData = NSData(bytes: response, length: response.count)
            responseData = encryptData(responseData)
            helloData.appendData(responseData)
        } else {
            var response: [UInt8] = [0x03]
            response.append(UInt8(request.host.utf8.count))
            response += [UInt8](request.host.utf8)
            var responseData = NSData(bytes: response, length: response.count)
            responseData = encryptData(responseData)
            helloData.appendData(responseData)
        }
        let portBytes = [UInt8](Utils.toByteArray(UInt16(request.port)).reverse())
        var responseData = NSData(bytes: portBytes, length: portBytes.count)
        responseData = encryptData(responseData)
        helloData.appendData(responseData)

        writeRawData(helloData, withTag: ShadowsocksTag.Connect.rawValue)
    }

    func writeRawData(data: NSData, withTag tag: Int) {
        super.writeData(data, withTag: tag)
    }

    override func readDataWithTag(tag: Int) {
        if readIV == nil && !readingIV {
            readingIV = true
            nextReadTag = tag
            socket.readDataToLength(ivLength, withTag: ShadowsocksTag.InitialVector.rawValue)
        } else {
            super.readDataWithTag(tag)
        }
    }

    override func writeData(data: NSData, withTag tag: Int) {
        writeRawData(encryptData(data), withTag: tag)
    }

    override func didReadData(data: NSData, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        if tag == ShadowsocksTag.InitialVector.rawValue {
            readIV = data
            readingIV = false
            super.didReadData(data, withTag: tag, from: socket)
            super.readDataWithTag(nextReadTag)
        } else {
            let readData = decryptData(data)
            super.didReadData(readData, withTag: tag, from: socket)
            delegate?.didReadData(readData, withTag: tag, from: self)
        }
    }

    override func didWriteData(data: NSData?, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didWriteData(nil, withTag: tag, from: socket)
        if tag == ShadowsocksTag.Connect.rawValue {
            delegate?.readyToForward(self)
        } else {
            delegate?.didWriteData(nil, withTag: tag, from: self)
        }
    }

    func encryptData(data: NSData) -> NSData {
        return encryptor.update(data)
    }

    func decryptData(data: NSData) -> NSData {
        return decryptor.update(data)
    }

    private func getCrypto(operation: CryptoOperation) -> StreamCryptoProtocol {
        switch encryptAlgorithm {
        case .AES128CFB, .AES192CFB, .AES256CFB:
            switch operation {
            case .Decrypt:
                return CCCrypto(operation: .Decrypt, mode: .CFB, algorithm: .AES, initialVector: readIV, key: key)
            case .Encrypt:
                return CCCrypto(operation: .Encrypt, mode: .CFB, algorithm: .AES, initialVector: writeIV, key: key)
            }
        case .CHACHA20:
            switch operation {
            case .Decrypt:
                return SodiumStreamCrypto(key: key, iv: readIV, algorithm: .Chacha20)
            case .Encrypt:
                return SodiumStreamCrypto(key: key, iv: writeIV, algorithm: .Chacha20)
            }
        case .SALSA20:
            switch operation {
            case .Decrypt:
                return SodiumStreamCrypto(key: key, iv: readIV, algorithm: .Salsa20)
            case .Encrypt:
                return SodiumStreamCrypto(key: key, iv: writeIV, algorithm: .Salsa20)
            }
        case .RC4MD5:
            let combinedKey = NSMutableData(capacity: key.length + ivLength)!
            combinedKey.appendData(key)
            switch operation {
            case .Decrypt:
                combinedKey.appendData(readIV)
                return CCCrypto(operation: .Decrypt, mode: .RC4, algorithm: .RC4, initialVector: nil, key: MD5Hash.final(combinedKey))
            case .Encrypt:
                combinedKey.appendData(writeIV)
                return CCCrypto(operation: .Encrypt, mode: .RC4, algorithm: .RC4, initialVector: nil, key: MD5Hash.final(combinedKey))
            }
        }
    }
}
