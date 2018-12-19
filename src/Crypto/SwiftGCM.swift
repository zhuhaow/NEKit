// SwiftGCM.swift
// By Luke Park, 2018

/*
 https://github.com/luke-park/SwiftGCM
 https://crypto.stackexchange.com/questions/17999/aes256-gcm-can-someone-explain-how-to-use-it-securely-ruby
 
 let key: Data = ...
 let nonce: Data = ...
 let plaintext: Data = ...
 let aad: Data = ...
 let tagSize = 16
 
 let gcmEnc: SwiftGCM = try SwiftGCM(key: key, nonce: nonce, tagSize:tagSize)
 let ciphertext: Data = try gcmEnc.encrypt(auth: aad, plaintext: plaintext)
 
 let gcmDec: SwiftGCM = try SwiftGCM(key: key, nonce: nonce, tagSize:tagSize)
 let result: Data = try gcmDec.decrypt(auth: aad, ciphertext: ciphertext)
 */

import Foundation
import CommonCrypto

public class SwiftGCM {
    private static let keySize128: Int = 16
    private static let keySize192: Int = 24
    private static let keySize256: Int = 32
    
    public static let tagSize128: Int = 16
    public static let tagSize120: Int = 15
    public static let tagSize112: Int = 14
    public static let tagSize104: Int = 13
    public static let tagSize96: Int = 12
    public static let tagSize64: Int = 8
    public static let tagSize32: Int = 4
    
    private static let standardNonceSize: Int = 12
    private static let blockSize: Int = 16
    
    private static let initialCounterSuffix: Data = Data(bytes: [0, 0, 0, 1])
    private static let emptyBlock: Data = Data(bytes: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    
    private let key: Data
    private let tagSize: Int
    private var counter: UInt_128
    
    private var h: UInt_128
    private var used: Bool
    
    // Constructor.
    init(key: Data, nonce: Data, tagSize: Int) throws {
        if tagSize != SwiftGCM.tagSize128 && tagSize != SwiftGCM.tagSize120 && tagSize != SwiftGCM.tagSize112 && tagSize != SwiftGCM.tagSize104 && tagSize != SwiftGCM.tagSize96 && tagSize != SwiftGCM.tagSize64 && tagSize != SwiftGCM.tagSize32 {
            throw SwiftGCMError.invalidTagSize
        }
        if key.count != SwiftGCM.keySize128 && key.count != SwiftGCM.keySize192 && key.count != SwiftGCM.keySize256 {
            throw SwiftGCMError.invalidKeySize
        }
        
        self.key = key
        self.tagSize = tagSize
        
        self.h = UInt_128(0)
        self.h = try UInt_128((SwiftGCM.encryptBlock(key: key, data: SwiftGCM.emptyBlock)))
        
        if nonce.count != SwiftGCM.standardNonceSize {
            self.counter = GaloisField.ghash(h: h, aad: Data(), ciphertext: nonce)
        } else {
            self.counter = SwiftGCM.makeCounter(nonce: nonce)
        }
        
        self.used = false
    }
    
    // Encrypt/Decrypt.
    public func encrypt(auth: Data?, plaintext: Data) throws -> Data {
        if used { throw SwiftGCMError.instanceAlreadyUsed }
        
        let dataPadded: Data = GaloisField.padToBlockSize(plaintext)
        let blockCount: Int = dataPadded.count / SwiftGCM.blockSize
        let h: Data = try SwiftGCM.encryptBlock(key: key, data: SwiftGCM.emptyBlock)
        let eky0: Data = try SwiftGCM.encryptBlock(key: key, data: counter.data)
        let authData: Data = (auth != nil ? auth! : Data())
        var ct: Data = Data()
        
        for i in 0..<blockCount {
            counter = counter.increment()
            let ekyi: Data = try SwiftGCM.encryptBlock(key: key, data: counter.data)
            
            let ptBlock: Data = dataPadded[dataPadded.startIndex + i * SwiftGCM.blockSize..<dataPadded.startIndex + i * SwiftGCM.blockSize + SwiftGCM.blockSize]
            ct.append(SwiftGCM.xorData(d1: ptBlock, d2: ekyi))
        }
        
        ct = ct[ct.startIndex..<ct.startIndex + plaintext.count]
        let ghash = GaloisField.ghash(h: UInt_128(h), aad: authData, ciphertext: ct)
        var t = (ghash ^ UInt_128(eky0)).data
        t = t[t.startIndex..<tagSize]
        
        var result: Data = Data()
        
        result.append(ct)
        result.append(t)
        
        used = true
        return result
    }
    
    public func decrypt(auth: Data?, ciphertext: Data) throws -> Data {
        if used { throw SwiftGCMError.instanceAlreadyUsed }
        
        let ct: Data = ciphertext[ciphertext.startIndex..<ciphertext.startIndex + ciphertext.count - SwiftGCM.blockSize]
        let givenT: Data = ciphertext[(ciphertext.startIndex + ciphertext.count - SwiftGCM.blockSize)...]
        
        let h: Data = try SwiftGCM.encryptBlock(key: key, data: SwiftGCM.emptyBlock)
        let eky0: Data = try SwiftGCM.encryptBlock(key: key, data: counter.data)
        let authData: Data = (auth != nil ? auth! : Data())
        let ghash = GaloisField.ghash(h: UInt_128(h), aad: authData, ciphertext: ct)
        var computedT = (ghash ^ UInt_128(eky0)).data
        computedT = computedT[computedT.startIndex..<tagSize]
        
        if !SwiftGCM.tsCompare(d1: computedT, d2: givenT) {
            throw SwiftGCMError.authTagValidation
        }
        
        let dataPadded: Data = GaloisField.padToBlockSize(ct)
        let blockCount: Int = dataPadded.count / SwiftGCM.blockSize
        
        var pt: Data = Data()
        
        for i in 0..<blockCount {
            counter = counter.increment()
            let ekyi: Data = try SwiftGCM.encryptBlock(key: key, data: counter.data)
            let ctBlock: Data = dataPadded[dataPadded.startIndex + i * SwiftGCM.blockSize..<dataPadded.startIndex + i * SwiftGCM.blockSize + SwiftGCM.blockSize]
            pt.append(SwiftGCM.xorData(d1: ctBlock, d2: ekyi))
        }
        
        pt = pt[0..<ct.count]
        
        used = true
        return pt
    }
    
    private static func encryptBlock(key: Data, data: Data) throws -> Data {
        if data.count != SwiftGCM.blockSize {
            throw SwiftGCMError.invalidDataSize
        }
        
        var dataMutable: Data = data
        var keyMutable: Data = key
        
        let operation: UInt32 = CCOperation(kCCEncrypt)
        let algorithm: UInt32 = CCAlgorithm(kCCAlgorithmAES)
        let options: UInt32 = CCOptions(kCCOptionECBMode)
        
        var ct: Data = Data(count: data.count)
        var num: size_t = 0
        
        let ct_count = ct.count
        let status = ct.withUnsafeMutableBytes { ctRaw in
            dataMutable.withUnsafeMutableBytes { dataRaw in
                keyMutable.withUnsafeMutableBytes{ keyRaw in
                    CCCrypt(operation, algorithm, options, keyRaw, key.count, nil, dataRaw, data.count, ctRaw, ct_count, &num)
                }
            }
        }
        
        if status != kCCSuccess {
            throw SwiftGCMError.commonCryptoError(err: status)
        }
        
        return ct
    }
    
    // Counter.
    private static func makeCounter(nonce: Data) -> UInt_128 {
        var result = Data()
        result.append(nonce)
        result.append(SwiftGCM.initialCounterSuffix)
        return UInt_128(result)
    }
    
    // Misc.
    private static func xorData(d1: Data, d2: Data) -> Data {
        var d1a: [UInt8] = [UInt8](d1)
        var d2a: [UInt8] = [UInt8](d2)
        var result: Data = Data(count: d1.count)
        
        for i in 0..<d1.count {
            let n1: UInt8 = d1a[i]
            let n2: UInt8 = d2a[i]
            result[i] = n1 ^ n2
        }
        
        return result
    }
    private static func tsCompare(d1: Data, d2: Data) -> Bool {
        if d1.count != d2.count { return false }
        
        var d1a: [UInt8] = [UInt8](d1)
        var d2a: [UInt8] = [UInt8](d2)
        var result: UInt8 = 0
        
        for i in 0..<d1.count {
            result |= d1a[i] ^ d2a[i]
        }
        
        return result == 0
    }
}

public enum SwiftGCMError: Error {
    case invalidKeySize
    case invalidDataSize
    case invalidTagSize
    case instanceAlreadyUsed
    case commonCryptoError(err: Int32)
    case authTagValidation
}



/// The Field GF(2^128)
private final class GaloisField {
    private static let r = UInt_128(a: 0xE100000000000000, b: 0)
    private static let blockSize: Int = 16
    
    // GHASH. One-time calculation
    static func ghash(x startx: UInt_128 = 0, h: UInt_128, aad: Data, ciphertext: Data) -> UInt_128 {
        var x = calculateX(aad: Array(aad), x: startx, h: h, blockSize: blockSize)
        x = calculateX(ciphertext: Array(ciphertext), x: x, h: h, blockSize: blockSize)
        
        // len(aad) || len(ciphertext)
        let len = UInt_128(a: UInt64(aad.count * 8), b: UInt64(ciphertext.count * 8))
        x = multiply((x ^ len), h)
        return x
    }
    
    
    // If data is not a multiple of block size bytes long then the remainder is zero padded
    // Note: It's similar to ZeroPadding, but it's not the same.
    static private func addPadding(_ bytes: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
        if bytes.isEmpty {
            return Array<UInt8>(repeating: 0, count: blockSize)
        }
        
        let remainder = bytes.count % blockSize
        if remainder == 0 {
            return bytes
        }
        
        let paddingCount = blockSize - remainder
        if paddingCount > 0 {
            return bytes + Array<UInt8>(repeating: 0, count: paddingCount)
        }
        return bytes
    }
    
    
    // Calculate Ciphertext part, for all blocks
    // Not used with incremental calculation.
    private static func calculateX(ciphertext: [UInt8], x startx: UInt_128, h: UInt_128, blockSize: Int) -> UInt_128 {
        let pciphertext = addPadding(ciphertext, blockSize: blockSize)
        let blocksCount = pciphertext.count / blockSize
        
        var x = startx
        for i in 0..<blocksCount {
            let cpos = i * blockSize
            let block = pciphertext[pciphertext.startIndex.advanced(by: cpos)..<pciphertext.startIndex.advanced(by: cpos + blockSize)]
            x = calculateX(block: Array(block), x: x, h: h, blockSize: blockSize)
        }
        return x
    }
    
    // block is expected to be padded with addPadding
    private static func calculateX(block ciphertextBlock: Array<UInt8>, x: UInt_128, h: UInt_128, blockSize: Int) -> UInt_128 {
        let k = x ^ UInt_128(ciphertextBlock)
        return multiply(k, h)
    }
    
    // Calculate AAD part, for all blocks
    private static func calculateX(aad: [UInt8], x startx: UInt_128, h: UInt_128, blockSize: Int) -> UInt_128 {
        let paad = addPadding(aad, blockSize: blockSize)
        let blocksCount = paad.count / blockSize
        
        var x = startx
        for i in 0..<blocksCount {
            let apos = i * blockSize
            let k = x ^ UInt_128(paad[paad.startIndex.advanced(by: apos)..<paad.startIndex.advanced(by: apos + blockSize)])
            x = multiply(k, h)
        }
        
        return x
    }
    
    // Multiplication GF(2^128).
    private static func multiply(_ x: UInt_128, _ y: UInt_128) -> UInt_128 {
        var z: UInt_128 = 0
        var v = x
        var k = UInt_128(a: 1 << 63, b: 0)
        
        for _ in 0..<128 {
            if y & k == k {
                z = z ^ v
            }
            
            if v & 1 != 1 {
                v = v >> 1
            } else {
                v = (v >> 1) ^ r
            }
            
            k = k >> 1
        }
        
        return z
    }
    
    // Padding.
    public static func padToBlockSize(_ x: Data) -> Data {
        let count: Int = blockSize - x.count % blockSize
        var result: Data = Data()
        
        result.append(x)
        for _ in 1...count {
            result.append(0)
        }
        
        return result
    }
}


struct UInt_128: Equatable, ExpressibleByIntegerLiteral {
    let i: (a: UInt64, b: UInt64)
    
    typealias IntegerLiteralType = UInt64
    
    init(integerLiteral value: IntegerLiteralType) {
        self = UInt_128(value)
    }
    
    init(_ raw: Array<UInt8>) {
        self = raw.prefix(MemoryLayout<UInt_128>.stride).withUnsafeBytes({ (rawBufferPointer) -> UInt_128 in
            let arr = rawBufferPointer.bindMemory(to: UInt64.self)
            return UInt_128((arr[0].bigEndian, arr[1].bigEndian))
        })
    }
    
    init(_ raw: Data) {
        self.init(Array(raw))
    }
    
    init(_ raw: ArraySlice<UInt8>) {
        self.init(Array(raw))
    }
    
    init(_ i: (a: UInt64, b: UInt64)) {
        self.i = i
    }
    
    init(a: UInt64, b: UInt64) {
        self.init((a, b))
    }
    
    init(_ b: UInt64) {
        self.init((0, b))
    }
    
    // Data
    var data: Data {
        var at = i.a.bigEndian
        var bt = i.b.bigEndian
        
        let ar = Data(bytes: &at, count: MemoryLayout.size(ofValue: at))
        let br = Data(bytes: &bt, count: MemoryLayout.size(ofValue: bt))
        
        var result = Data()
        result.append(ar)
        result.append(br)
        return result
    }
    
    
    // Successive counter values are generated using the function incr(), which treats the rightmost 32
    // bits of its argument as a nonnegative integer with the least significant bit on the right
    func increment() -> UInt_128 {
        let b = self.i.b + 1
        let a = (b == 0 ? self.i.a + 1 : self.i.a)
        return UInt_128((a, b))
    }
    
    
    static func ^(n1: UInt_128, n2: UInt_128) -> UInt_128 {
        return UInt_128((n1.i.a ^ n2.i.a, n1.i.b ^ n2.i.b))
    }
    
    static func &(n1: UInt_128, n2: UInt_128) -> UInt_128 {
        return UInt_128((n1.i.a & n2.i.a, n1.i.b & n2.i.b))
    }
    
    static func >>(value: UInt_128, by: Int) -> UInt_128 {
        var result = value
        for _ in 0..<by {
            let a = result.i.a >> 1
            let b = result.i.b >> 1 + ((result.i.a & 1) << 63)
            result = UInt_128((a, b))
        }
        return result
    }
    
    // Equatable.
    static func ==(lhs: UInt_128, rhs: UInt_128) -> Bool {
        return lhs.i == rhs.i
    }
    
    static func !=(lhs: UInt_128, rhs: UInt_128) -> Bool {
        return !(lhs == rhs)
    }
}
