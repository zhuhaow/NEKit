import Foundation
import Sodium

class SodiumStreamCrypto: StreamCryptoProtocol {
    enum Alogrithm {
        case Chacha20, Salsa20
    }

    let key: NSData
    let iv: NSData
    let algorithm: Alogrithm

    var counter = 0

    let blockSize = 64

    init(key: NSData, iv: NSData, algorithm: Alogrithm) {
        Libsodium.initialized
        self.key = key
        self.iv = iv
        self.algorithm = algorithm
    }

    func update(data: NSData) -> NSData {
        let len = data.length % blockSize

        var outputData: NSMutableData
        if len != 0 {
            outputData = NSMutableData(length: data.length + len)!
            outputData.replaceBytesInRange(NSRange(location: len, length: data.length), withBytes: data.bytes)
        } else {
            outputData = NSMutableData(data: data)
        }

        switch algorithm {
        case .Chacha20:
            crypto_stream_chacha20_xor_ic(UnsafeMutablePointer<UInt8>(outputData.mutableBytes), UnsafePointer<UInt8>(outputData.bytes), UInt64(outputData.length), UnsafePointer<UInt8>(iv.bytes), UInt64(counter/blockSize), UnsafePointer<UInt8>(key.bytes))
        case .Salsa20:
            crypto_stream_salsa20_xor_ic(UnsafeMutablePointer<UInt8>(outputData.mutableBytes), UnsafePointer<UInt8>(outputData.bytes), UInt64(outputData.length), UnsafePointer<UInt8>(iv.bytes), UInt64(counter/blockSize), UnsafePointer<UInt8>(key.bytes))
        }

        if len == 0 {
            return outputData
        } else {
            return outputData.subdataWithRange(NSRange(location: len, length: data.length))
        }
    }
}
