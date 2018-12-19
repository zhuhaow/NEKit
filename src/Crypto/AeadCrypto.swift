import Foundation
import Sodium
import CommonCrypto
import CocoaLumberjackSwift

open class AeadCrypto {

    private var nonce = [UInt8](repeating: 0, count: 12)
    private var nonceData: Data {
        get {
            return Data(bytes: nonce)
        }
    }

    private func checkNonceSize(_ size: Int) {
        if size > 0,
            nonce.count != size {
            nonce = [UInt8](repeating: 0, count: size)
        }
    }

    private func nonceIncrement() {
        sodium_increment(UnsafeMutablePointer(mutating: nonce), nonce.count)
    }

    private let skey: Data
    private let algorithm: CryptoAlgorithm
    private let tagSize: Int


    public init(algorithm: CryptoAlgorithm, skey: Data, tagSize: Int, nonceSize: Int) {

        self.skey = skey
        self.algorithm = algorithm
        self.tagSize = tagSize
        checkNonceSize(nonceSize)
    }


    /*
     """
     Encrypt data with authenticate tag
     :param data: plain text
     :return: data [payload][tag] cipher text with tag
     """
     */
    func aeadEncrypt(_ data: Data) -> Data {
        switch algorithm {
        case .AES128GCM, .AES192GCM, .AES256GCM:
            if let gcmEnc = try? SwiftGCM(key: skey, nonce: nonceData, tagSize: tagSize),
                let ciphertext = try? gcmEnc.encrypt(auth: nil, plaintext: data) {
                nonceIncrement()
                return ciphertext
            }

        case .CHACHA20POLY1305:
            var ciphertextLen: UInt64 = UInt64(data.count + tagSize)
            var ciphertext = [UInt8](repeating: 0, count: Int(ciphertextLen))

            let cryptoResult = data.withUnsafeBytes { (dataBytes: UnsafePointer<UInt8>) in
                skey.withUnsafeBytes { keyBytes  in
                    crypto_aead_chacha20poly1305_ietf_encrypt(&ciphertext, &ciphertextLen, dataBytes, UInt64(data.count), nil, 0, nil, &nonce, keyBytes)
                }
            }

            if cryptoResult==0 {
                nonceIncrement()
                return Data(bytes: ciphertext)
            }

        default:
            DDLogError("AEAD algorithm not implemented")
            return Data()
        }

        return Data()
    }


    /*
     """
     Decrypt data and authenticate tag
     :param data: data [len][tag][payload][tag] cipher text with tag
     :return: data plain text
     """
     */
    func aeadDecrypt(_ data: Data) -> Data {
        switch algorithm {
        case .AES128GCM, .AES192GCM, .AES256GCM:
            if let gcmDec = try? SwiftGCM(key: skey, nonce: nonceData, tagSize: tagSize),
                let result = try? gcmDec.decrypt(auth: nil, ciphertext: data) {
                nonceIncrement()
                return result
            }

        case .CHACHA20POLY1305:
            var decryptedLen: UInt64 = UInt64(data.count - tagSize)
            var decrypted = [UInt8](repeating: 0, count: Int(decryptedLen))

            let cryptoResult = data.withUnsafeBytes { (dataBytes: UnsafePointer<UInt8>) in
                skey.withUnsafeBytes { keyBytes  in
                    crypto_aead_chacha20poly1305_ietf_decrypt(&decrypted, &decryptedLen, nil, dataBytes, UInt64(data.count), nil, 0, &nonce, keyBytes)
                }
            }

            if cryptoResult==0 && Int(decryptedLen)==data.count - tagSize {
                nonceIncrement()
                return Data(bytes: decrypted)
            }

        default:
            DDLogError("AEAD algorithm not implemented")
            return Data()
        }

        return Data()
    }

}
