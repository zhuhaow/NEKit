//
//  CryptoAeadProcessor.swift
//  PacketTunnel
//
//  Created by Hanson on 2018/12/9.
//  Copyright © 2018 Nobody. All rights reserved.
//

import Foundation
extension ShadowsocksAdapter {

    /*
     https://shadowsocks.org/en/spec/AEAD-Ciphers.html
     Key Derivation
     HKDF_SHA1 is a function that takes a secret key, a non-secret salt, an info string, and produces a subkey that is cryptographically strong even if the input secret key is weak.

     HKDF_SHA1(key, salt, info) => subkey
     The info string binds the generated subkey to a specific application context. In our case, it must be the string "ss-subkey" without quotes.

     We derive a per-session subkey from a pre-shared master key using HKDF_SHA1. Salt must be unique through the entire life of the pre-shared master key.


     Authenticated Encryption/Decryption
     AE_encrypt is a function that takes a secret key, a non-secret nonce, a message, and produces ciphertext and authentication tag. Nonce must be unique for a given key in each invocation.

     AE_encrypt(key, nonce, message) => (ciphertext, tag)
     AE_decrypt is a function that takes a secret key, non-secret nonce, ciphertext, authentication tag, and produces original message. If any of the input is tampered with, decryption will fail.

     AE_decrypt(key, nonce, ciphertext, tag) => message

     TCP
     An AEAD encrypted TCP stream starts with a randomly generated salt to derive the per-session subkey, followed by any number of encrypted chunks. Each chunk has the following structure:

     [encrypted payload length][length tag][encrypted payload][payload tag]
     Payload length is a 2-byte big-endian unsigned integer capped at 0x3FFF. The higher two bits are reserved and must be set to zero. Payload is therefore limited to 16*1024 - 1 bytes.

     The first AEAD encrypt/decrypt operation uses a counting nonce starting from 0. After each encrypt/decrypt operation, the nonce is incremented by one as if it were an unsigned little-endian integer. Note that each TCP chunk involves two AEAD encrypt/decrypt operation: one for the payload length, and one for the payload. Therefore each chunk increases the nonce twice.


     """
     Handles basic aead process of shadowsocks protocol

     TCP Chunk (after encryption, *ciphertext*)
     +--------------+---------------+--------------+------------+
     |  *DataLen*   |  DataLen_TAG  |    *Data*    |  Data_TAG  |
     +--------------+---------------+--------------+------------+
     |      2       |     Fixed     |   Variable   |   Fixed    |
     +--------------+---------------+--------------+------------+

     UDP (after encryption, *ciphertext*)
     +--------+-----------+-----------+
     | NONCE  |  *Data*   |  Data_TAG |
     +-------+-----------+-----------+
     | Fixed  | Variable  |   Fixed   |
     +--------+-----------+-----------+
     """

     */


    public class CryptoAeadProcessor: CryptoStreamProcessor {
        private var encryptor: AeadCrypto?
        private var decryptor: AeadCrypto?

        private var skey: Data = Data()
        var chunkSize = 0
        let subkey = "ss-subkey"
        let chunkSizeLen = 2
        let chunkSizeMask = 0x3FFF

        override init(key: Data, algorithm: CryptoAlgorithm) {
            super.init(key: key, algorithm: algorithm)

            skey = HKDF.deriveKey(ikm: key,
                                  salt: writeIV,
                                  info: subkey.data(using: .utf8)!,
                                  algorithm: .SHA1,
                                  count: key.count)

            encryptor = AeadCrypto(algorithm: algorithm,
                                   skey: skey,
                                   tagSize: tagSize,
                                   nonceSize: nonceSize)
        }


        lazy var nonceSize: Int = {
            [unowned self] in
            CryptoHelper.getNonceSize(algorithm)
            }()

        lazy var tagSize: Int = {
            [unowned self] in
            CryptoHelper.getTagSize(algorithm)
            }()


        public override func input(data: Data) throws {
            var data = data

            if readIV == nil {
                buffer.append(data: data)
                readIV = buffer.get(length: ivLength)
                guard readIV != nil else {
                    try inputStreamProcessor!.input(data: Data())
                    return
                }

                data = buffer.get() ?? Data()
                buffer.reset()
                decryptor = AeadCrypto(algorithm: algorithm,
                                       skey: HKDF.deriveKey(ikm: key,
                                                            salt: readIV,
                                                            info: subkey.data(using: .utf8)!,
                                                            algorithm: .SHA1,
                                                            count: key.count),
                                       tagSize: tagSize,
                                       nonceSize: nonceSize)
            }
            try inputStreamProcessor!.input(data: decryptAll(data))
        }

        public override func output(data: Data) {
            var data = encryptAll(data)

            if sendKey {
                outputStreamProcessor!.output(data: data)
            } else {
                sendKey = true

                var out = Data(capacity: data.count + writeIV.count)
                out.append(writeIV)
                out.append(data)

                outputStreamProcessor!.output(data: out)
            }
        }

        /*
         """
         Encrypt data, for TCP divided into chunks
         For UDP data, call aead_encrypt instead
         :param data: data data bytes
         :return: data encrypted data
         """
         */
        func encryptAll(_ data: Data) -> Data {
            if data.count <= chunkSizeMask {
                return encryptChunk(data)
            } else {
                var ctext = Data()

                var index = data.startIndex
                while index != data.endIndex {
                    let startIndex = index
                    let endIndex = data.index(index, offsetBy: chunkSizeMask, limitedBy: data.endIndex) ?? data.endIndex
                    let range = startIndex ..< endIndex
                    let chunk = data[range]

                    ctext.append(encryptChunk(chunk))
                    index = endIndex
                }

                return ctext
            }
        }

        /*
         """
         Encrypt a chunk for TCP chunks
         :param data
         :return: data [len][tag][payload][tag]
         """
         */
        func encryptChunk(_ data: Data) -> Data {
            let plen = UInt16(data.count & chunkSizeMask)
            // l = CHUNK_SIZE_LEN + plen + tagSize * 2

            // network byte order
            var t = plen.bigEndian
            let td = Data(bytes: &t, count: chunkSizeLen)
            var ctext = encryptor!.aeadEncrypt(td)
            ctext.append(encryptor!.aeadEncrypt(data))
            return ctext
        }



        /*
         """
         Decrypt data for TCP data divided into chunks
         For UDP data, call aead_decrypt instead
         :param data: data
         :return: data
         """
         */
        func decryptAll(_ data: Data) -> Data {
            var ptext = Data()
            var (pnext, left) = decryptChunk(data)
            ptext.append(pnext)

            while left.count > 0 {
                (pnext, left) = decryptChunk(left)
                ptext.append(pnext)
            }
            return ptext
        }

        /*
         """
         Decrypt a TCP chunk
         :param data: data [len][tag][payload][tag][[len][tag]...] encrypted msg
         :return: (data, data) decrypted msg and remaining encrypted data
         """
         */
        func decryptChunk(_ data: Data) -> (Data, Data) {
            let (plen, data) = decryptChunkSize(data)
            if plen<=0 {
                return (Data(), Data())
            } else {
                return decryptChunkPayload(plen, data)
            }
        }

        /*
         """
         Decrypt chunk size
         :param data: data [size][tag] encrypted chunk payload len
         :return: (int, data) msg length and remaining encrypted data
         """
         */
        func decryptChunkSize(_ data: Data) -> (Int, Data) {
            if chunkSize > 0 {
                return (chunkSize, data)
            }

            var mdata = buffer.get() ?? Data()
            mdata.append(data)

            let hlen = chunkSizeLen + tagSize
            if mdata.count < hlen {
                buffer.replace(data: mdata)
                return (0, Data())
            }

            let ldata = decryptor!.aeadDecrypt(mdata.subdata(in: 0 ..< hlen))
            let bytes = [UInt8](ldata)
            let plen = Int(bytes[0]) * 256 + Int(bytes[1])
            if plen > chunkSizeMask || plen < 0 {
                return (0, Data())
            }

            return (plen, mdata.subdata(in: hlen ..< mdata.count))
        }

        /*
         """
         Decrypted encrypted msg payload
         :param plen: int payload length
         :param data: data [payload][tag][[len][tag]....] encrypted data
         :return: (data, data) plain text and remaining encrypted data
         """
         */
        func decryptChunkPayload(_ plen:Int, _ data: Data) -> (Data, Data) {
            var mdata = buffer.get() ?? Data()
            mdata.append(data)

            if mdata.count < plen + tagSize {
                chunkSize = plen
                buffer.replace(data: mdata)
                return (Data(), Data())
            }

            chunkSize = 0
            buffer.reset()

            let plaintext = decryptor!.aeadDecrypt(mdata.subdata(in: 0 ..< plen+tagSize))
            if  plaintext.count != plen {
                return (Data(), Data())
            }

            return (plaintext, mdata.subdata(in: plen+tagSize ..< mdata.count))
        }
        
    }

}

