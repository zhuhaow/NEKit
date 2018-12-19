import Foundation

public struct CryptoHelper {
    // Key Size , IV Length (Salt Size), Nonce Size, Tag Size
    public static let infoDictionary: [CryptoAlgorithm:(Int, Int, Int, Int)] = [
        .AES128CFB: (16, 16, 0, 0),
        .AES192CFB: (24, 16, 0, 0),
        .AES256CFB: (32, 16, 0, 0),
        .CHACHA20: (32, 8, 0, 0),
        .SALSA20: (32, 8, 0, 0),
        .RC4MD5: (16, 16, 0, 0),
        // AEAD
        .AES128GCM: (16, 16, 12, 16),
        .AES192GCM: (24, 24, 12, 16),
        .AES256GCM: (32, 32, 12, 16),
        .CHACHA20POLY1305: (32, 32, 12, 16)
    ]
    
    public static func getKeyLength(_ methodType: CryptoAlgorithm) -> Int {
        return infoDictionary[methodType]!.0
    }
    
    public static func getIVLength(_ methodType: CryptoAlgorithm) -> Int {
        return infoDictionary[methodType]!.1
    }
    
    public static func getNonceSize(_ methodType: CryptoAlgorithm) -> Int {
        return infoDictionary[methodType]!.2
    }
    
    public static func getTagSize(_ methodType: CryptoAlgorithm) -> Int {
        return infoDictionary[methodType]!.3
    }
    
    public static func getIV(_ methodType: CryptoAlgorithm) -> Data {
        let c = getIVLength(methodType)
        var IV = Data(count: c)
        _ = IV.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, c, $0)
        }
        return IV
    }
    
    public static func EVP_BytesToKey(_ password: String, methodType: CryptoAlgorithm) -> Data {
        var result = Data(count: getIVLength(methodType) + getKeyLength(methodType))
        let passwordData = password.data(using: String.Encoding.utf8)!
        var md5result = MD5Hash.final(password)
        var extendPasswordData = Data(count: passwordData.count + md5result.count)
        
        extendPasswordData.replaceSubrange(md5result.count..<extendPasswordData.count, with: passwordData)
        
        var length = 0
        repeat {
            let copyLength = min(result.count - length, md5result.count)
            result.withUnsafeMutableBytes {
                md5result.copyBytes(to: $0.advanced(by: length), count: copyLength)
            }
            extendPasswordData.replaceSubrange(0..<md5result.count, with: md5result)
            md5result = MD5Hash.final(extendPasswordData)
            length += copyLength
        } while length < result.count
        
        return result.subdata(in: 0..<getKeyLength(methodType))
    }
}
