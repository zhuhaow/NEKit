import Foundation
import CommonCrypto

public enum CryptoOperation {
    case Encrypt, Decrypt

    public func toCCOperation() -> CCOperation {
        switch self {
        case .Encrypt:
            return CCOperation(kCCEncrypt)
        case .Decrypt:
            return CCOperation(kCCDecrypt)
        }
    }
}

public enum CryptoAlgorithm: String {
    case AES128CFB = "AES-128-CFB", AES192CFB = "AES-192-CFB", AES256CFB = "AES-256-CFB", CHACHA20 = "chacha20", SALSA20 = "salsa20", RC4MD5 = "rc4-md5"
}
