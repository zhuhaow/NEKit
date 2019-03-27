import Foundation
import CommonCrypto

open class CCCrypto: StreamCryptoProtocol {
    public enum Algorithm {
        case aes, cast, rc4

        public func toCCAlgorithm() -> CCAlgorithm {
            switch self {
            case .aes:
                return CCAlgorithm(kCCAlgorithmAES)
            case .rc4:
                return CCAlgorithm(kCCAlgorithmRC4)
            case .cast:
                return CCAlgorithm(kCCAlgorithmCAST)
            }
        }
    }

    public enum Mode {
        case cfb, rc4

        public func toCCMode() -> CCMode {
            switch self {
            case .cfb:
                return CCMode(kCCModeCFB)
            case .rc4:
                return CCMode(kCCModeRC4)
            }
        }
    }

    let cryptor: CCCryptorRef

    public init(operation: CryptoOperation, mode: Mode, algorithm: Algorithm, initialVector: Data?, key: Data) {
        let cryptor = UnsafeMutablePointer<CCCryptorRef?>.allocate(capacity: 1)
        _ = key.withUnsafeBytes { k in
            if let initialVector = initialVector {
                _ = initialVector.withUnsafeBytes { iv in
                    CCCryptorCreateWithMode(operation.toCCOperation(), mode.toCCMode(), algorithm.toCCAlgorithm(), CCPadding(ccNoPadding), iv.baseAddress!, k.baseAddress!, key.count, nil, 0, 0, 0, cryptor)
                }
            } else {
                CCCryptorCreateWithMode(operation.toCCOperation(), mode.toCCMode(), algorithm.toCCAlgorithm(), CCPadding(ccNoPadding), nil, k.baseAddress!, key.count, nil, 0, 0, 0, cryptor)
            }
        }
        self.cryptor = cryptor.pointee!
    }

    open func update( _ data: inout Data) {
        let count = data.count
        _ = data.withUnsafeMutableBytes {
            CCCryptorUpdate(cryptor, $0.baseAddress!, count, $0.baseAddress!, count, nil)
        }
    }

    deinit {
        CCCryptorRelease(cryptor)
    }

}
