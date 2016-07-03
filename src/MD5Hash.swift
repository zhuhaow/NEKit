import Foundation
import CommonCrypto

struct MD5Hash {
    static func final(value: String) -> NSData {
        let data = value.dataUsingEncoding(NSUTF8StringEncoding)!
        return final(data)
    }

    static func final(value: NSData) -> NSData {
        let result = NSMutableData(length: Int(CC_MD5_DIGEST_LENGTH))!
        CC_MD5(value.bytes, CC_LONG(value.length), UnsafeMutablePointer<UInt8>(result.mutableBytes))
        return NSData(data: result)
    }
}
