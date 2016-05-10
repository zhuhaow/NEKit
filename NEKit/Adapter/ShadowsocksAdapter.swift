import Foundation
import CommonCrypto

class ShadowsocksAdapter: AdapterSocket {
    var readIV: NSData!
    let key: NSData
    let encryptMethod: EncryptMethod
    let host: String
    let port: Int
    
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
        Cryptor(op: .Encrypt, mode: .CFB, alg: .AES, iv: self.writeIV, key: self.key)
    }()
    lazy var decryptor: Cryptor = {
        [unowned self] in
        Cryptor(op: .Decrypt, mode: .CFB, alg: .AES, iv: self.readIV, key: self.key)
    }()
    
    enum EncryptMethod: String {
        case AES128CFB = "AES-128-CFB", AES192CFB = "AES-192-CFB", AES256CFB = "AES-256-CFB"
        
        static let allValues: [EncryptMethod] = [.AES128CFB, .AES192CFB, .AES256CFB]
    }
    
    enum ShadowsocksTag: Int {
        case IV = 25000, Connect
    }
    
    init(host: String, port: Int, encryptMethod: EncryptMethod, password: String) {
        self.encryptMethod = encryptMethod
        (self.key, _) = ShadowsocksEncryptHelper.getKeyAndIV(password, methodType: encryptMethod)
        self.host = host
        self.port = port
        super.init()
    }
    
    
    override func didConnect(socket: RawSocketProtocol) {
        super.didConnect(socket)
        
        let helloData = NSMutableData(data: writeIV)
        if request.isIPv4() {
            var response :[UInt8] = [0x01]
            response += Utils.IP.IPv4ToBytes(request.host)!
            var responseData = NSData(bytes: &response, length: response.count)
            responseData = encryptData(responseData)
            helloData.appendData(responseData)
        } else if request.isIPv6() {
            var response :[UInt8] = [0x04]
            response += Utils.IP.IPv6ToBytes(request.host)!
            var responseData = NSData(bytes: &response, length: response.count)
            responseData = encryptData(responseData)
            helloData.appendData(responseData)
        } else {
            var response :[UInt8] = [0x03]
            response.append(UInt8(request.host.utf8.count))
            response += [UInt8](request.host.utf8)
            var responseData = NSData(bytes: &response, length: response.count)
            responseData = encryptData(responseData)
            helloData.appendData(responseData)
        }
        var portBytes = Utils.toByteArray(UInt16(request.port)).reverse()
        var responseData = NSData(bytes: &portBytes, length: portBytes.count)
        responseData = encryptData(responseData)
        helloData.appendData(responseData)
        
        writeRawData(helloData, withTag: ShadowsocksTag.Connect.rawValue)
        readDataToLength(ivLength, withTag: ShadowsocksTag.IV.rawValue)
    }
    
    func writeRawData(data: NSData, withTag tag: Int) {
        super.writeData(data, withTag: tag)
    }
    
    override func writeData(data: NSData, withTag tag: Int) {
        writeRawData(encryptData(data), withTag: tag)
    }
    
    override func didReadData(data: NSData, withTag tag: Int, from socket: RawSocketProtocol) {
        if tag == ShadowsocksTag.IV.rawValue {
            readIV = data
            delegate?.readyForForward(self)
        } else {
            super.didReadData(decryptData(data), withTag: tag, from: socket)
        }
    }
    
    override func didWriteData(data: NSData?, withTag tag: Int, from socket: RawSocketProtocol) {
        if tag == ShadowsocksTag.Connect.rawValue {
            // do nothing
        } else {
            super.didWriteData(data, withTag: tag, from: socket)
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

    
    init(op: Operation, mode: Mode, alg: Algorithm, iv: NSData, key: NSData) {
        let cryptor = UnsafeMutablePointer<CCCryptorRef>.alloc(1)
        CCCryptorCreateWithMode(op.op(), mode.mode(), alg.algorithm(), CCPadding(ccNoPadding), iv.bytes, key.bytes, key.length, nil, 0, 0, 0, cryptor)
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
    static let infoDictionary: [ShadowsocksAdapter.EncryptMethod:(Int,Int)] = [
        .AES128CFB:(16,16),
        .AES192CFB:(24,16),
        .AES256CFB:(32,16),
    ]
    
    static func getKeyLength(methodType: ShadowsocksAdapter.EncryptMethod) -> Int {
        return infoDictionary[methodType]!.0
    }
    
    static func getIVLength(methodType: ShadowsocksAdapter.EncryptMethod) -> Int {
        return infoDictionary[methodType]!.1
    }
    
//    static func getKey(password: String, methodType: ShadowsocksAdapter.EncryptMethod) -> NSData {
//        let key = NSMutableData(length: getKeyLength(methodType))!
//        let passwordData = password.dataUsingEncoding(NSUTF8StringEncoding)!
//        let extendPasswordData = NSMutableData(length: passwordData.length + 1)!
//        passwordData.getBytes(extendPasswordData.mutableBytes + 1, length: passwordData.length)
//        var md5result = Utils.Crypto.MD5(password)
//        var length = 0
//        var i = 0
//        repeat {
//            let copyLength = min(key.length - length, md5result.length)
//            md5result.getBytes(key.mutableBytes + length, length: copyLength)
//            extendPasswordData.replaceBytesInRange(NSRange(location: i, length: 1), withBytes: key.bytes)
//            md5result = Utils.Crypto.MD5(extendPasswordData)
//            length += copyLength
//            i += 1
//        } while length < key.length
//        return NSData(data: key)
//    }
    
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
        var i = 0
        repeat {
            let copyLength = min(result.length - length, md5result.length)
            md5result.getBytes(result.mutableBytes + length, length: copyLength)
            extendPasswordData.replaceBytesInRange(NSRange(location: 0, length: md5result.length), withBytes: md5result.bytes)
            md5result = Utils.Crypto.MD5(extendPasswordData)
            length += copyLength
            i += 1
        } while length < result.length
        return (result.subdataWithRange(NSRange(location: 0, length: key.length)), result.subdataWithRange(NSRange(location: key.length, length: iv.length)))
    }
}