import Foundation

extension ShadowsocksAdapter {
    public class CryptoStreamProcessor {
        public class Factory {
            let password: String
            let algorithm: CryptoAlgorithm
            let key: Data

            public init(password: String, algorithm: CryptoAlgorithm) {
                self.password = password
                self.algorithm = algorithm
                key = CryptoHelper.getKey(password, methodType: algorithm)
            }

            public func build() -> CryptoStreamProcessor {
                return CryptoStreamProcessor(key: key, algorithm: algorithm)
            }
        }

        public weak var inputStreamProcessor: StreamObfuscater.StreamObfuscaterBase!
        public weak var outputStreamProcessor: ProtocolObfuscater.ProtocolObfuscaterBase!

        var readIV: Data!
        let key: Data
        let algorithm: CryptoAlgorithm

        var sendKey = false

        var buffer = Buffer(capacity: 0)

        lazy var writeIV: Data = {
            [unowned self] in
            CryptoHelper.getIV(self.algorithm)
            }()
        lazy var ivLength: Int = {
            [unowned self] in
            CryptoHelper.getIVLength(self.algorithm)
            }()
        lazy var encryptor: StreamCryptoProtocol = {
            [unowned self] in
            self.getCrypto(.encrypt)
            }()
        lazy var decryptor: StreamCryptoProtocol = {
            [unowned self] in
            self.getCrypto(.decrypt)
            }()

        init(key: Data, algorithm: CryptoAlgorithm) {
            self.key = key
            self.algorithm = algorithm
        }

        func encrypt(data: inout Data) {
            return encryptor.update(&data)
        }

        func decrypt(data: inout Data) {
            return decryptor.update(&data)
        }

        public func input(data: Data) throws {
            var data = data

            if readIV == nil {
                buffer.append(data: data)
                readIV = buffer.get(length: ivLength)
                guard readIV != nil else {
                    try inputStreamProcessor!.input(data: Data())
                    return
                }

                data = buffer.get() ?? Data()
                buffer.release()
            }

            decrypt(data: &data)
            try inputStreamProcessor!.input(data: data)
        }

        public func output(data: Data) {
            var data = data
            encrypt(data: &data)
            if sendKey {
                return outputStreamProcessor!.output(data: data)
            } else {
                sendKey = true
                var out = Data(capacity: data.count + writeIV.count)
                out.append(writeIV)
                out.append(data)

                return outputStreamProcessor!.output(data: out)
            }
        }

        private func getCrypto(_ operation: CryptoOperation) -> StreamCryptoProtocol {
            switch algorithm {
            case .AES128CFB, .AES192CFB, .AES256CFB:
                switch operation {
                case .decrypt:
                    return CCCrypto(operation: .decrypt, mode: .cfb, algorithm: .aes, initialVector: readIV, key: key)
                case .encrypt:
                    return CCCrypto(operation: .encrypt, mode: .cfb, algorithm: .aes, initialVector: writeIV, key: key)
                }
            case .CHACHA20:
                switch operation {
                case .decrypt:
                    return SodiumStreamCrypto(key: key, iv: readIV, algorithm: .chacha20)
                case .encrypt:
                    return SodiumStreamCrypto(key: key, iv: writeIV, algorithm: .chacha20)
                }
            case .SALSA20:
                switch operation {
                case .decrypt:
                    return SodiumStreamCrypto(key: key, iv: readIV, algorithm: .salsa20)
                case .encrypt:
                    return SodiumStreamCrypto(key: key, iv: writeIV, algorithm: .salsa20)
                }
            case .RC4MD5:
                var combinedKey = Data(capacity: key.count + ivLength)
                combinedKey.append(key)
                switch operation {
                case .decrypt:
                    combinedKey.append(readIV)
                    return CCCrypto(operation: .decrypt, mode: .rc4, algorithm: .rc4, initialVector: nil, key: MD5Hash.final(combinedKey))
                case .encrypt:
                    combinedKey.append(writeIV)
                    return CCCrypto(operation: .encrypt, mode: .rc4, algorithm: .rc4, initialVector: nil, key: MD5Hash.final(combinedKey))
                }
            }
        }
    }
}
