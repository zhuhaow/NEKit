import Foundation

extension ShadowsocksAdapter {
    public struct StreamObfuscater {
        public class Factory {
            public init() {}
            
            public func build(for request: ConnectRequest) -> StreamObfuscaterBase {
                return StreamObfuscaterBase(for: request)
            }
        }

        public class StreamObfuscaterBase {
            public weak var inputStreamProcessor: ShadowsocksAdapter!
            private weak var _outputStreamProcessor: CryptoStreamProcessor!
            public var outputStreamProcessor: CryptoStreamProcessor! {
                get {
                    return _outputStreamProcessor
                }
                set {
                    _outputStreamProcessor = newValue
                    key = _outputStreamProcessor?.key
                    writeIV = _outputStreamProcessor?.writeIV
                }
            }

            public var key: Data?
            public var writeIV: Data?

            let request: ConnectRequest

            init(for request: ConnectRequest) {
                self.request = request
            }

            func output(data: Data) {}
            func input(data: Data) throws {}
        }

        public class OriginStreamObfuscater: StreamObfuscaterBase {
            public class Factory: StreamObfuscater.Factory {
                public init() {}
                
                public override func build(for request: ConnectRequest) -> ShadowsocksAdapter.StreamObfuscater.StreamObfuscaterBase {
                    return OriginStreamObfuscater(for: request)
                }
            }

            private var requestSend = false

            private func requestData(withData data: Data) -> Data {
                let hostLength = request.host.utf8.count
                let length = 1 + 1 + hostLength + 2 + data.count
                var response = Data(count: length)
                response.withUnsafeMutableBytes { (pointer: UnsafeMutablePointer<UInt8>) in
                    pointer.pointee = 3
                    pointer.successor().pointee = UInt8(hostLength)
                }
                response.replaceSubrange(2..<2+hostLength, with: request.host.utf8)
                var beport = UInt16(request.port).bigEndian
                withUnsafeBytes(of: &beport) {
                    response.replaceSubrange(2+hostLength..<4+hostLength, with: $0)
                }
                response.replaceSubrange(4+hostLength..<length, with: data)
                return response
            }

            public override func input(data: Data) throws {
                inputStreamProcessor!.input(data: data)
            }

            public override func output(data: Data) {
                if requestSend {
                    return outputStreamProcessor!.output(data: data)
                } else {
                    requestSend = true
                    return outputStreamProcessor!.output(data: requestData(withData: data))
                }
            }
        }

        public class OTAStreamObfuscater: StreamObfuscaterBase {
            public class Factory: StreamObfuscater.Factory {
                public override func build(for request: ConnectRequest) -> ShadowsocksAdapter.StreamObfuscater.StreamObfuscaterBase {
                    return OTAStreamObfuscater(for: request)
                }
            }

            private var count: UInt32 = 0

            private let DATA_BLOCK_SIZE = 0xFFFF - 12

            private var requestSend = false

            private func requestData() -> Data {
                var response: [UInt8] = [0x13]
                response.append(UInt8(request.host.utf8.count))
                response += [UInt8](request.host.utf8)
                response += [UInt8](Utils.toByteArray(UInt16(request.port)).reversed())
                var responseData = Data(bytes: UnsafePointer<UInt8>(response), count: response.count)
                var keyiv = Data(count: key!.count + writeIV!.count)

                keyiv.replaceSubrange(0..<writeIV!.count, with: writeIV!)
                keyiv.replaceSubrange(writeIV!.count..<writeIV!.count + key!.count, with: key!)
                responseData.append(HMAC.final(value: responseData, algorithm: .SHA1, key: keyiv).subdata(in: 0..<10))
                return responseData
            }

            public override func input(data: Data) throws {
                inputStreamProcessor!.input(data: data)
            }

            public override func output(data: Data) {
                let fullBlockCount = data.count / DATA_BLOCK_SIZE
                var outputSize = fullBlockCount * (DATA_BLOCK_SIZE + 10 + 2)
                if data.count > fullBlockCount * DATA_BLOCK_SIZE {
                    outputSize += data.count - fullBlockCount * DATA_BLOCK_SIZE + 10 + 2
                }

                let _requestData: Data = requestData()
                if !requestSend {
                    outputSize += _requestData.count
                }

                var outputData = Data(count: outputSize)
                var outputOffset = 0
                var dataOffset = 0

                if !requestSend {
                    requestSend = true
                    outputData.replaceSubrange(0..<_requestData.count, with: _requestData)
                    outputOffset += _requestData.count
                }

                while outputOffset != outputSize {
                    let blockLength = min(data.count - dataOffset, DATA_BLOCK_SIZE)
                    var len = UInt16(blockLength).bigEndian
                    withUnsafeBytes(of: &len) {
                        outputData.replaceSubrange(outputOffset..<outputOffset+2, with: $0)
                    }

                    var kc = Data(count: writeIV!.count + MemoryLayout.size(ofValue: count))
                    kc.replaceSubrange(0..<writeIV!.count, with: writeIV!)
                    var c = count.bigEndian
                    withUnsafeBytes(of: &c) {
                        kc.replaceSubrange(writeIV!.count..<writeIV!.count+MemoryLayout.size(ofValue: c), with: $0)
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

                return outputStreamProcessor!.output(data: outputData)
            }
        }
    }
}
