import Foundation
import CommonCrypto

public struct MD5Hash {
    public static func final(_ value: String) -> Data {
        let data = value.data(using: String.Encoding.utf8)!
        return final(data)
    }

    public static func final(_ value: Data) -> Data {
        var result = Data(count: Int(CC_MD5_DIGEST_LENGTH))
        _ = value.withUnsafeBytes { v in
            result.withUnsafeMutableBytes { res in
                CC_MD5(v.baseAddress!, CC_LONG(value.count), res.bindMemory(to: UInt8.self).baseAddress!)
            }
        }

        return result
    }
}
