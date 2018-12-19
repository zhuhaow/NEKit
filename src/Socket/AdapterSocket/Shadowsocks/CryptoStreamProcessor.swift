import Foundation
import CocoaLumberjackSwift

extension ShadowsocksAdapter {
    public class CryptoStreamProcessor {
        public class Factory {
            let password: String
            let algorithm: CryptoAlgorithm
            let key: Data
            
            public init(password: String, algorithm: CryptoAlgorithm) {
                self.password = password
                self.algorithm = algorithm
                key = CryptoHelper.EVP_BytesToKey(password, methodType: algorithm)
            }
            
            public func build() -> CryptoStreamProcessor {
                if algorithm.isAead {
                    return CryptoAeadProcessor(key: key, algorithm: algorithm)
                } else {
                    return CryptoStreamProcessor(key: key, algorithm: algorithm)
                }
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
            CryptoHelper.getIV(algorithm)
            }()
        lazy var ivLength: Int = {
            [unowned self] in
            CryptoHelper.getIVLength(algorithm)
            }()
        
        private lazy var encryptor: StreamCryptoProtocol? = {
            [unowned self] in
            self.getCrypto(.encrypt)
            }()
        private lazy var decryptor: StreamCryptoProtocol? = {
            [unowned self] in
            self.getCrypto(.decrypt)
            }()
        
        init(key: Data, algorithm: CryptoAlgorithm) {
            self.key = key
            self.algorithm = algorithm
        }
        
        private func encrypt(data: inout Data) {
            if let encryptor = encryptor {
                encryptor.update(&data)
            } else {
                DDLogError("no encryptor for \(algorithm.rawValue)")
            }
        }
        
        private func decrypt(data: inout Data) {
            if let decryptor = decryptor {
                decryptor.update(&data)
            } else {
                DDLogError("no decryptor for \(algorithm.rawValue)")
            }
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
                buffer.reset()
            }
            
            decrypt(data: &data)
            try inputStreamProcessor!.input(data: data)
        }
        
        public func output(data: Data) {
            var data = data
            encrypt(data: &data)
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
        
        private func getCrypto(_ operation: CryptoOperation) -> StreamCryptoProtocol? {
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
                
            default:
                return nil
            }
        }
    }
    
}



