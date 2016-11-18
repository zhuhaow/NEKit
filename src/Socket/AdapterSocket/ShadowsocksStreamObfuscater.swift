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
}
