import Foundation
import CommonCrypto

enum CryptoOperation {
    case Encrypt, Decrypt

    func toCCOperation() -> CCOperation {
        switch self {
        case .Encrypt:
            return CCOperation(kCCEncrypt)
        case .Decrypt:
            return CCOperation(kCCDecrypt)
        }
    }
}
