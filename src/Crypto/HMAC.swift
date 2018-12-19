import Foundation
import CommonCrypto

public class HMAC {

    public static func final(value: String, algorithm: HashAlgorithm, key: Data) -> Data {
        let data = value.data(using: String.Encoding.utf8)!
        return final(value: data, algorithm: algorithm, key: key)
    }

    public static func final(value: Data, algorithm: HashAlgorithm, key: Data) -> Data {
        var result = Data(count: algorithm.digestLength)
        _ = value.withUnsafeRawPointer { v in
            result.withUnsafeMutableBytes { res in
                key.withUnsafeRawPointer { k in
                    CCHmac(algorithm.HMACAlgorithm, k, key.count, v, value.count, res)
                }
            }
        }

        return result
    }

    public static func final(value: UnsafeRawPointer, length: Int, algorithm: HashAlgorithm, key: Data) -> Data {
        var result = Data(count: algorithm.digestLength)

        _ = result.withUnsafeMutableBytes { res in
            key.withUnsafeRawPointer { k in
                CCHmac(algorithm.HMACAlgorithm, k, key.count, value, length, res)
            }
        }

        return result
    }


    var context: CCHmacContext = CCHmacContext()
    var algorithm: HashAlgorithm

    public init(algorithm: HashAlgorithm, key: Data) {
        self.algorithm = algorithm
        key.withUnsafeBytes { bytes in
            CCHmacInit(&context, algorithm.HMACAlgorithm, bytes, key.count)
        }
    }

    public func update(data: Data) -> Self {
        data.withUnsafeBytes { bytes  in
            CCHmacUpdate(&context, bytes, data.count)
        }
        return self
    }

    public func update(byteArray: [UInt8]) -> Self {
        CCHmacUpdate(&context, byteArray, byteArray.count)
        return self
    }

    public func final() -> Data {
        let count = algorithm.digestLength
        var hmac = [UInt8](repeating: 0, count: count)
        CCHmacFinal(&context, &hmac)
        return Data(bytes: hmac)
    }
    
}
