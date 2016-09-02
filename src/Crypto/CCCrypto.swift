import Foundation
import CommonCrypto

public class CCCrypto: StreamCryptoProtocol {
    public enum Algorithm {
        case AES, CAST, RC4

        public func toCCAlgorithm() -> CCAlgorithm {
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

    public enum Mode {
        case CFB, RC4

        public func toCCMode() -> CCMode {
            switch self {
            case .CFB:
                return CCMode(kCCModeCFB)
            case .RC4:
                return CCMode(kCCModeRC4)
            }
        }
    }

    let cryptor: CCCryptorRef

    public init(operation: CryptoOperation, mode: Mode, algorithm: Algorithm, initialVector: NSData?, key: NSData) {
        let cryptor = UnsafeMutablePointer<CCCryptorRef>.alloc(1)
        CCCryptorCreateWithMode(operation.toCCOperation(), mode.toCCMode(), algorithm.toCCAlgorithm(), CCPadding(ccNoPadding), initialVector?.bytes ?? nil, key.bytes, key.length, nil, 0, 0, 0, cryptor)
        self.cryptor = cryptor.memory
    }

    public func update(data: NSData) -> NSData {
        let outData = NSMutableData(length: data.length)!
        CCCryptorUpdate(cryptor, data.bytes, data.length, outData.mutableBytes, outData.length, nil)
        return NSData(data: outData)
    }

    deinit {
        CCCryptorRelease(cryptor)
    }

}
