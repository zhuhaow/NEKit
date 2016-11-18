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
        var count: Int = 0

        public func requestData(for request: ConnectRequest) -> Data {
            var response: [UInt8] = [0x13]
            response.append(UInt8(request.host.utf8.count))
            response += [UInt8](request.host.utf8)
            response += [UInt8](Utils.toByteArray(UInt16(request.port)).reversed())
            var responseData = Data(bytes: UnsafePointer<UInt8>(response), count: response.count)
            var keyiv = Data(capacity: key.count + iv.count)
            keyiv.replaceSubrange(0..<key.count, with: key)
            keyiv.replaceSubrange(key.count..<key.count + iv.count, with: iv)
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
            var outputData = Data(capacity: data.count + 10 + 2)
            var len = data.count.bigEndian
            withUnsafeBytes(of: &len) {
                outputData.replaceSubrange(0..<2, with: $0)
            }

            var kc = Data(capacity: iv.count + MemoryLayout.size(ofValue: len))
            kc.replaceSubrange(0..<iv.count, with: iv)
            var c = count.bigEndian
            withUnsafeBytes(of: &c) {
                outputData.replaceSubrange(0..<MemoryLayout.size(ofValue: c), with: $0)
            }

            let hash = HMAC.final(value: data, algorithm: .SHA1, key: kc).subdata(in: 0..<10)
            outputData.replaceSubrange(2..<12, with: hash)
            outputData.replaceSubrange(12..<outputData.count, with: data)

            count += 1

            return outputData
        }
    }
}
