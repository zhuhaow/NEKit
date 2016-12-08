import Foundation

public protocol ShadowsocksStreamObfuscater {
    init(key: Data, iv: Data)
    func requestData(for: ConnectRequest) -> Data
    func output(data: Data) -> Data
    func input(data: Data) -> Data
}

extension ShadowsocksAdapter {
    public class OriginStreamObfuscater: ShadowsocksStreamObfuscater {
        public func requestData(for request: ConnectRequest) -> Data {
            var response: [UInt8] = [0x03]
            response.append(UInt8(request.host.utf8.count))
            response += [UInt8](request.host.utf8)
            response += [UInt8](Utils.toByteArray(UInt16(request.port)).reversed())
            return Data(bytes: UnsafePointer<UInt8>(response), count: response.count)
        }

        required public init(key: Data, iv: Data) {

        }

        public func input(data: Data) -> Data {
            return data
        }

        public func output(data: Data) -> Data {
            return data
        }
    }

    public class OTAStreamObfuscater: ShadowsocksStreamObfuscater {
        let key: Data
        let iv: Data
        var count: UInt32 = 0

        let DATA_BLOCK_SIZE = 0xFFFF - 12

        public func requestData(for request: ConnectRequest) -> Data {
            var response: [UInt8] = [0x13]
            response.append(UInt8(request.host.utf8.count))
            response += [UInt8](request.host.utf8)
            response += [UInt8](Utils.toByteArray(UInt16(request.port)).reversed())
            var responseData = Data(bytes: UnsafePointer<UInt8>(response), count: response.count)
            var keyiv = Data(count: key.count + iv.count)

            keyiv.replaceSubrange(0..<iv.count, with: iv)
            keyiv.replaceSubrange(iv.count..<iv.count + key.count, with: key)
            responseData.append(HMAC.final(value: responseData, algorithm: .SHA1, key: keyiv).subdata(in: 0..<10))
            return responseData
        }

        required public init(key: Data, iv: Data) {
            self.key = key
            self.iv = iv
        }

        public func input(data: Data) -> Data {
            return data
        }

        public func output(data: Data) -> Data {
            let fullBlockCount = data.count / DATA_BLOCK_SIZE
            var outputSize = fullBlockCount * (DATA_BLOCK_SIZE + 10 + 2)
            if data.count > fullBlockCount * DATA_BLOCK_SIZE {
                outputSize += data.count - fullBlockCount * DATA_BLOCK_SIZE + 10 + 2
            }
            var outputData = Data(count: outputSize)
            var outputOffset = 0
            var dataOffset = 0

            while outputOffset != outputSize {
                let blockLength = min(data.count - dataOffset, DATA_BLOCK_SIZE)
                var len = UInt16(blockLength).bigEndian
                withUnsafeBytes(of: &len) {
                    outputData.replaceSubrange(outputOffset..<outputOffset+2, with: $0)
                }

                var kc = Data(count: iv.count + MemoryLayout.size(ofValue: count))
                kc.replaceSubrange(0..<iv.count, with: iv)
                var c = count.bigEndian
                withUnsafeBytes(of: &c) {
                    kc.replaceSubrange(iv.count..<iv.count+MemoryLayout.size(ofValue: c), with: $0)
                }

                data.withUnsafeRawPointer {
                    outputData.replaceSubrange(outputOffset+2..<outputOffset+12, with: HMAC.final(value: $0.advanced(by: dataOffset), length: blockLength, algorithm: .SHA1, key: kc).subdata(in: 0..<10))
                }

                data.withUnsafeBytes {
                    outputData.replaceSubrange(outputOffset+12..<outputOffset+12+blockLength, with: UnsafeBufferPointer(start: $0.advanced(by: dataOffset), count: blockLength))
                }

                count += 1
                outputOffset += 12 + blockLength
                dataOffset += blockLength
            }

            return outputData
        }
    }

    //    public class AuthSha1V4StreamObfuscater: ShadowsocksStreamObfuscater {
    //        let key: Data
    //        let iv: Data
    //
    //        required public init(key: Data, iv: Data) {
    //            self.key = key
    //            self.iv = iv
    //        }
    //
    //        public func requestData(for: ConnectRequest) -> Data {
    //            let currentTime = Int32(truncatingBitPattern: Int(Date().timeIntervalSince1970))
    //
    //        }
    //
    //        public func input(data: Data) -> Data {
    //
    //        }
    //
    //        public func output(data: Data) -> Data {
    //
    //        }
    //
    //        func randomData(length: Int) -> Data {
    //            if length > 1200 {
    //                return Data(bytes: [0x01])
    //            }
    //
    //            let maxlen: UInt32 = length > 400 ? 256 : 512
    //            let dataLen = Int(arc4random_uniform(maxlen))
    //            var result: Data
    //            if dataLen < 128 {
    //                result = Data(capacity: dataLen + 1)
    //                result[0] = UInt8(dataLen + 1)
    //                result.withUnsafeMutableBytes {
    //                    arc4random_buf($0.advanced(by: 1), dataLen)
    //                }
    //            } else {
    //                result = Data(capacity: dataLen + 3)
    //                result[0] = 255
    //                var len = UInt16(dataLen + 3).bigEndian
    //                withUnsafeBytes(of: &len) {
    //                    result.replaceSubrange(1..<3, with: $0)
    //                }
    //                result.withUnsafeMutableBytes {
    //                    arc4random_buf($0.advanced(by: 3), dataLen)
    //                }
    //
    //            }
    //            return result
    //        }
    //    }
}
