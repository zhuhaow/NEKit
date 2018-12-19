//
//  AeadCrypto.swift
//  PacketTunnel
//
//  Created by Hanson on 2018/12/11.
//  Copyright © 2018 Nobody. All rights reserved.
//

import Foundation
import Sodium
import CommonCrypto
import CocoaLumberjackSwift

open class AeadCrypto {
    
    private var nonce = [UInt8](repeating: 0, count: 12)
    private var nonceData:Data {
        get {
            return Data(bytes: nonce)
        }
    }
    
    private func checkNonceSize( _ size: Int) {
        if size > 0,
            nonce.count != size {
            nonce = [UInt8](repeating: 0, count: size)
        }
    }
    
    private func nonce_increment() {
        sodium_increment(UnsafeMutablePointer(mutating: nonce), nonce.count)
    }
    
    private let skey: Data
    private let algorithm: CryptoAlgorithm
    private let tagSize: Int
    
    
    public init(algorithm: CryptoAlgorithm, skey: Data, tagSize: Int, nonceSize:Int) {
        
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
    func aead_encrypt( _ data: Data) -> Data {
        switch algorithm {
        case .AES128GCM, .AES192GCM, .AES256GCM:
            if let gcmEnc = try? SwiftGCM(key: skey, nonce: nonceData, tagSize:tagSize),
                let ciphertext = try? gcmEnc.encrypt(auth: nil, plaintext: data) {
                nonce_increment()
                return ciphertext
            }
            
        case .CHACHA20POLY1305:
            var ciphertext_len:UInt64 = UInt64(data.count + tagSize)
            var ciphertext = [UInt8](repeating: 0, count: Int(ciphertext_len))
            
            let crypto_result = data.withUnsafeBytes { (data_bytes: UnsafePointer<UInt8>) in
                skey.withUnsafeBytes({ (key_bytes)  in
                    crypto_aead_chacha20poly1305_ietf_encrypt(&ciphertext, &ciphertext_len,
                                                              data_bytes, UInt64(data.count),
                                                              nil, 0,
                                                              nil,
                                                              &nonce, key_bytes)
                })
            }
            
            if crypto_result==0 {
                nonce_increment()
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
    func aead_decrypt(data: Data) -> Data {
        switch algorithm {
        case .AES128GCM, .AES192GCM, .AES256GCM:
            if let gcmDec = try? SwiftGCM(key: skey, nonce: nonceData, tagSize:tagSize),
                let result = try? gcmDec.decrypt(auth: nil, ciphertext: data) {
                nonce_increment()
                return result
            }
            
        case .CHACHA20POLY1305:
            var decrypted_len:UInt64 = UInt64(data.count - tagSize)
            var decrypted = [UInt8](repeating: 0, count: Int(decrypted_len))
            
            let crypto_result = data.withUnsafeBytes { (data_bytes: UnsafePointer<UInt8>) in
                skey.withUnsafeBytes({ (key_bytes)  in
                    crypto_aead_chacha20poly1305_ietf_decrypt(&decrypted, &decrypted_len,
                                                              nil,
                                                              data_bytes, UInt64(data.count),
                                                              nil, 0,
                                                              &nonce, key_bytes)
                })
            }
            
            if crypto_result==0 && Int(decrypted_len)==data.count - tagSize {
                nonce_increment()
                return Data(bytes: decrypted)
            }
            
        default:
            DDLogError("AEAD algorithm not implemented")
            return Data()
        }
        
        return Data()
        
    }
    
    
}






