import Foundation
import CommonCrypto

/// This adapter connects to remote through Shadowsocks proxy.
class ShadowsocksAdapter: AdapterSocket {
    var readIV: NSData!
    let key: NSData
    let encryptMethod: EncryptMethod
    let host: String
    let port: Int

    var readingIV: Bool = false
    var nextReadTag: Int = 0

    lazy var writeIV: NSData = {
        [unowned self] in
        ShadowsocksEncryptHelper.getIV(self.encryptMethod)
    }()
    lazy var ivLength: Int = {
        [unowned self] in
        ShadowsocksEncryptHelper.getIVLength(self.encryptMethod)
    }()
    lazy var encryptor: Cryptor = {
        [unowned self] in
        Cryptor(operation: .Encrypt, mode: .CFB, algorithm: .AES, initialVector: self.writeIV, key: self.key)
    }()
    lazy var decryptor: Cryptor = {
        [unowned self] in
        Cryptor(operation: .Decrypt, mode: .CFB, algorithm: .AES, initialVector: self.readIV, key: self.key)
    }()

    enum EncryptMethod: String {
        case AES128CFB = "AES-128-CFB", AES192CFB = "AES-192-CFB", AES256CFB = "AES-256-CFB"

        static let allValues: [EncryptMethod] = [.AES128CFB, .AES192CFB, .AES256CFB]
    }

    enum ShadowsocksTag: Int {
        case InitialVector = 25000, Connect
    }

    init(host: String, port: Int, encryptMethod: EncryptMethod, password: String) {
        self.encryptMethod = encryptMethod
        (self.key, _) = ShadowsocksEncryptHelper.getKeyAndIV(password, methodType: encryptMethod)
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

    func readDataWithTag(tag: Int) {
        if readIV == nil && !readingIV {
            readingIV = true
            socket.readDataToLength(ivLength, withTag: ShadowsocksTag.InitialVector.rawValue)
            nextReadTag = tag
        } else {
            super.readDataWithTag(tag)
        }
    }

    func writeData(data: NSData, withTag tag: Int) {
        writeRawData(encryptData(data), withTag: tag)
    }

    override func didReadData(data: NSData, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didReadData(decryptData(data), withTag: tag, from: socket)
        if tag == ShadowsocksTag.InitialVector.rawValue {
            readIV = data
            readingIV = false
            super.readDataWithTag(nextReadTag)
        } else {
            delegate?.didReadData(decryptData(data), withTag: tag, from: self)
        }
    }

    override func didWriteData(data: NSData?, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didWriteData(data, withTag: tag, from: socket)
        if tag == ShadowsocksTag.Connect.rawValue {
            delegate?.readyToForward(self)
        } else {
            delegate?.didWriteData(data, withTag: tag, from: self)
        }
    }

    func encryptData(data: NSData) -> NSData {
        return encryptor.update(data)
    }

    func decryptData(data: NSData) -> NSData {
        return decryptor.update(data)
    }
}

class Cryptor {
    enum Operation {
        case Encrypt, Decrypt

        func op() -> CCOperation {
            switch self {
            case .Encrypt:
                return CCOperation(kCCEncrypt)
            case .Decrypt:
                return CCOperation(kCCDecrypt)
            }
        }
    }

    enum Algorithm {
        case AES, CAST, RC4

        func algorithm() -> CCAlgorithm {
            switch self {
            case .AES:
                return CCAlgorithm(kCCAlgorithmAES)
            case .RC4:
                return CCAlgorithm(kCCAlgorithmRC4)
            case .CAST:
                return CCAlgorithm(kCCAlgorithmCAST)
            }
        }
    }

    enum Mode {
        case CFB

        func mode() -> CCMode {
            switch self {
            case .CFB:
                return CCMode(kCCModeCFB)
            }
        }
    }

    let cryptor: CCCryptorRef


    init(operation: Operation, mode: Mode, algorithm: Algorithm, initialVector: NSData, key: NSData) {
        let cryptor = UnsafeMutablePointer<CCCryptorRef>.alloc(1)
        CCCryptorCreateWithMode(operation.op(), mode.mode(), algorithm.algorithm(), CCPadding(ccNoPadding), initialVector.bytes, key.bytes, key.length, nil, 0, 0, 0, cryptor)
        self.cryptor = cryptor.memory
    }

    func update(data: NSData) -> NSData {
        let outData = NSMutableData(length: data.length)!
        CCCryptorUpdate(cryptor, data.bytes, data.length, outData.mutableBytes, outData.length, nil)
        return NSData(data: outData)
    }

    deinit {
        CCCryptorRelease(cryptor)
    }

}

struct ShadowsocksEncryptHelper {
    static let infoDictionary: [ShadowsocksAdapter.EncryptMethod:(Int, Int)] = [
        .AES128CFB:(16, 16),
        .AES192CFB:(24, 16),
        .AES256CFB:(32, 16),
    ]

    static func getKeyLength(methodType: ShadowsocksAdapter.EncryptMethod) -> Int {
        return infoDictionary[methodType]!.0
    }

    static func getIVLength(methodType: ShadowsocksAdapter.EncryptMethod) -> Int {
        return infoDictionary[methodType]!.1
    }

    static func getIV(methodType: ShadowsocksAdapter.EncryptMethod) -> NSData {
        let IV = NSMutableData(length: getIVLength(methodType))!
        SecRandomCopyBytes(kSecRandomDefault, IV.length, UnsafeMutablePointer<UInt8>(IV.mutableBytes))
        return NSData(data: IV)
    }

    static func getKeyAndIV(password: String, methodType: ShadowsocksAdapter.EncryptMethod) -> (NSData, NSData) {
        let key = NSMutableData(length: getKeyLength(methodType))!
        let iv = NSMutableData(length: getIVLength(methodType))!
        let result = NSMutableData(length: getIVLength(methodType) + getKeyLength(methodType))!
        let passwordData = password.dataUsingEncoding(NSUTF8StringEncoding)!
        var md5result = Utils.Crypto.MD5(password)
        let extendPasswordData = NSMutableData(length: passwordData.length + md5result.length)!
        passwordData.getBytes(extendPasswordData.mutableBytes + md5result.length, length: passwordData.length)
        var length = 0
        repeat {
            let copyLength = min(result.length - length, md5result.length)
            md5result.getBytes(result.mutableBytes + length, length: copyLength)
            extendPasswordData.replaceBytesInRange(NSRange(location: 0, length: md5result.length), withBytes: md5result.bytes)
            md5result = Utils.Crypto.MD5(extendPasswordData)
            length += copyLength
        } while length < result.length
        return (result.subdataWithRange(NSRange(location: 0, length: key.length)), result.subdataWithRange(NSRange(location: key.length, length: iv.length)))
    }
}
