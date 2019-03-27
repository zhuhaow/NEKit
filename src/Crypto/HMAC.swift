import Foundation
import CommonCrypto

public struct HMAC {

    public static func final(value: String, algorithm: HashAlgorithm, key: Data) -> Data {
        let data = value.data(using: String.Encoding.utf8)!
        return final(value: data, algorithm: algorithm, key: key)
    }

    public static func final(value: Data, algorithm: HashAlgorithm, key: Data) -> Data {
        var result = Data(count: algorithm.digestLength)
        _ = value.withUnsafeBytes { v in
                result.withUnsafeMutableBytes { res in
                    key.withUnsafeBytes { k in
                        CCHmac(algorithm.HMACAlgorithm, k.baseAddress!, key.count, v.baseAddress!, value.count, res.baseAddress!)
                    }
                }
        }

        return result
    }

    public static func final(value: UnsafeRawPointer, length: Int, algorithm: HashAlgorithm, key: Data) -> Data {
        var result = Data(count: algorithm.digestLength)

        _ = result.withUnsafeMutableBytes { res in
                key.withUnsafeBytes { k in
                    CCHmac(algorithm.HMACAlgorithm, k.baseAddress!, key.count, value, length, res.baseAddress!)
                }
            }

        return result
    }
}
