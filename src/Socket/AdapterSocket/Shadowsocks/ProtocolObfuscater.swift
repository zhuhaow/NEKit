import Foundation

extension ShadowsocksAdapter {
    public struct ProtocolObfuscater {
        public class Factory {
            public init() {}

            public func build() -> ProtocolObfuscaterBase {
                return ProtocolObfuscaterBase()
            }
        }

        public class ProtocolObfuscaterBase {
            public weak var inputStreamProcessor: CryptoStreamProcessor!
            public weak var outputStreamProcessor: ShadowsocksAdapter!

            public func start() {}
            public func input(data: Data) throws {}
            public func output(data: Data) {}

            public func didWrite() {}
        }

        public class OriginProtocolObfuscater: ProtocolObfuscaterBase {

            public class Factory: ProtocolObfuscater.Factory {
                public override init() {}

                public override func build() -> ShadowsocksAdapter.ProtocolObfuscater.ProtocolObfuscaterBase {
                    return OriginProtocolObfuscater()
                }
            }

            public override func start() {
                outputStreamProcessor.becomeReadyToForward()
            }

            public override func input(data: Data) throws {
                try inputStreamProcessor.input(data: data)
            }

            public override func output(data: Data) {
                outputStreamProcessor.output(data: data)
            }
        }

        public class HTTPProtocolObfuscater: ProtocolObfuscaterBase {

            public class Factory: ProtocolObfuscater.Factory {
                let method: String
                let hosts: [String]
                let customHeader: String?

                public init(method: String = "GET", hosts: [String], customHeader: String?) {
                    self.method = method
                    self.hosts = hosts
                    self.customHeader = customHeader
                }

                public override func build() -> ShadowsocksAdapter.ProtocolObfuscater.ProtocolObfuscaterBase {
                    return HTTPProtocolObfuscater(method: method, hosts: hosts, customHeader: customHeader)
                }
            }

            static let headerLength = 30
            static let userAgent = ["Mozilla/5.0 (Windows NT 6.3; WOW64; rv:40.0) Gecko/20100101 Firefox/40.0",
                                    "Mozilla/5.0 (Windows NT 6.3; WOW64; rv:40.0) Gecko/20100101 Firefox/44.0",
                                    "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36",
                                    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Ubuntu/11.10 Chromium/27.0.1453.93 Chrome/27.0.1453.93 Safari/537.36",
                                    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:35.0) Gecko/20100101 Firefox/35.0",
                                    "Mozilla/5.0 (compatible; WOW64; MSIE 10.0; Windows NT 6.2)",
                                    "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/533.20.25 (KHTML, like Gecko) Version/5.0.4 Safari/533.20.27",
                                    "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.3; Trident/7.0; .NET4.0E; .NET4.0C)",
                                    "Mozilla/5.0 (Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko",
                                    "Mozilla/5.0 (Linux; Android 4.4; Nexus 5 Build/BuildID) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/30.0.0.0 Mobile Safari/537.36",
                                    "Mozilla/5.0 (iPad; CPU OS 5_0 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A334 Safari/7534.48.3",
                                    "Mozilla/5.0 (iPhone; CPU iPhone OS 5_0 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A334 Safari/7534.48.3"]

            let method: String
            let hosts: [String]
            let customHeader: String?

            var readingFakeHeader = false
            var sendHeader = false
            var remaining = false

            var buffer = Buffer(capacity: 8192)

            public init(method: String = "GET", hosts: [String], customHeader: String?) {
                self.method = method
                self.hosts = hosts
                self.customHeader = customHeader
            }

            private func generateHeader(encapsulating data: Data) -> String {
                let ind = Int(arc4random_uniform(UInt32(hosts.count)))
                let host = outputStreamProcessor.port == 80 ? hosts[ind] : "\(hosts[ind]):\(outputStreamProcessor.port)"
                var header = "\(method) /\(hexlify(data: data)) HTTP/1.1\r\nHost: \(host)\r\n"
                if let customHeader = customHeader {
                    header += customHeader
                } else {
                    let ind = Int(arc4random_uniform(UInt32(HTTPProtocolObfuscater.userAgent.count)))
                    header += "User-Agent: \(HTTPProtocolObfuscater.userAgent[ind])\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\nAccept-Language: en-US,en;q=0.8\r\nAccept-Encoding: gzip, deflate\r\nDNT: 1\r\nConnection: keep-alive"
                }
                header += "\r\n\r\n"
                return header
            }

            private func hexlify(data: Data) -> String {
                var result = ""
                for i in data {
                    result = result.appendingFormat("%%%02x", i)
                }
                return result
            }

            public override func start() {
                readingFakeHeader = true
                outputStreamProcessor.becomeReadyToForward()
            }

            public override func input(data: Data) throws {
                if readingFakeHeader {
                    buffer.append(data: data)
                    if buffer.get(to: Utils.HTTPData.DoubleCRLF) != nil {
                        readingFakeHeader = false
                        if let remainData = buffer.get() {
                            try inputStreamProcessor.input(data: remainData)
                            return
                        }
                    }
                    try inputStreamProcessor.input(data: Data())
                    return
                }

                try inputStreamProcessor.input(data: data)
            }

            public override func output(data: Data) {
                if sendHeader {
                    outputStreamProcessor.output(data: data)
                } else {
                    var fakeRequestDataLength = inputStreamProcessor.key.count + HTTPProtocolObfuscater.headerLength
                    if data.count - fakeRequestDataLength > 64 {
                        fakeRequestDataLength += Int(arc4random_uniform(64))
                    } else {
                        fakeRequestDataLength = data.count
                    }

                    var outputData = generateHeader(encapsulating: data.subdata(in: 0 ..< fakeRequestDataLength)).data(using: .utf8)!
                    outputData.append(data.subdata(in: fakeRequestDataLength ..< data.count))
                    sendHeader = true
                    outputStreamProcessor.output(data: outputData)
                }
            }
        }

        public class TLSProtocolObfuscater: ProtocolObfuscaterBase {

            public class Factory: ProtocolObfuscater.Factory {
                let hosts: [String]

                public init(hosts: [String]) {
                    self.hosts = hosts
                }

                public override func build() -> ShadowsocksAdapter.ProtocolObfuscater.ProtocolObfuscaterBase {
                    return TLSProtocolObfuscater(hosts: hosts)
                }
            }

            let hosts: [String]
            let clientID: Data = {
                var id = Data(count: 32)
                Utils.Random.fill(data: &id)
                return id
            }()

            private var status = 0

            private var buffer = Buffer(capacity: 1024)

            init(hosts: [String]) {
                self.hosts = hosts
            }

            public override func start() {
                handleStatus0()
                outputStreamProcessor.socket.readDataTo(length: 129)
            }

            public override func input(data: Data) throws {
                switch status {
                case 8:
                    try handleInput(data: data)
                case 1:
                    outputStreamProcessor.becomeReadyToForward()
                default:
                    break
                }
            }

            public override func output(data: Data) {
                switch status {
                case 8:
                    handleStatus8(data: data)
                    return
                case 1:
                    handleStatus1(data: data)
                    return
                default:
                    break
                }
            }

            private func authData() -> Data {
                var time = UInt32(Date.init().timeIntervalSince1970).bigEndian
                var output = Data(count: 32)
                var key = inputStreamProcessor.key
                key.append(clientID)

                withUnsafeBytes(of: &time) {
                    output.replaceSubrange(0 ..< 4, with: $0)
                }

                Utils.Random.fill(data: &output, from: 4, length: 18)
                output.withUnsafeBytes {
                    output.replaceSubrange(22 ..< 32, with: HMAC.final(value: $0.baseAddress!, length: 22, algorithm: .SHA1, key: key).subdata(in: 0..<10))
                }
                return output
            }

            private func pack(data: Data) -> Data {
                var output = Data()
                var left = data.count
                while left > 0 {
                    let blockSize = UInt16(min(Int(arc4random_uniform(UInt32(UInt16.max))) % 4096 + 100, left))
                    var blockSizeBE = blockSize.bigEndian
                    output.append(contentsOf: [0x17, 0x03, 0x03])
                    withUnsafeBytes(of: &blockSizeBE) {
                        output.append($0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: $0.count)
                    }
                    output.append(data.subdata(in: data.count - left ..< data.count - left + Int(blockSize)))
                    left -= Int(blockSize)
                }
                return output
            }

            private func handleStatus8(data: Data) {
                outputStreamProcessor.output(data: pack(data: data))
            }

            private func handleStatus0() {
                status = 1

                var outData = Data()
                outData.append(contentsOf: [0x03, 0x03])
                outData.append(authData())
                outData.append(0x20)
                outData.append(clientID)
                outData.append(contentsOf: [0x00, 0x1c, 0xc0, 0x2b, 0xc0, 0x2f, 0xcc, 0xa9, 0xcc, 0xa8, 0xcc, 0x14, 0xcc, 0x13, 0xc0, 0x0a, 0xc0, 0x14, 0xc0, 0x09, 0xc0, 0x13, 0x00, 0x9c, 0x00, 0x35, 0x00, 0x2f, 0x00, 0x0a])
                outData.append("0100".data(using: .utf8)!)

                var extData = Data()
                extData.append(contentsOf: [0xff, 0x01, 0x00, 0x01, 0x00])
                let hostData = hosts[Int(arc4random_uniform(UInt32(hosts.count)))].data(using: .utf8)!

                var sniData = Data(capacity: hosts.count + 2 + 1 + 2 + 2 + 2)

                sniData.append(contentsOf: [0x00, 0x00])

                var _lenBE = UInt16(hostData.count + 5).bigEndian
                withUnsafeBytes(of: &_lenBE) {
                    sniData.append($0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: $0.count)
                }

                _lenBE = UInt16(hostData.count + 3).bigEndian
                withUnsafeBytes(of: &_lenBE) {
                    sniData.append($0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: $0.count)
                }

                sniData.append(0x00)

                _lenBE = UInt16(hostData.count).bigEndian
                withUnsafeBytes(of: &_lenBE) {
                    sniData.append($0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: $0.count)
                }

                sniData.append(hostData)

                extData.append(sniData)

                extData.append(contentsOf: [0x00, 0x17, 0x00, 0x00, 0x00, 0x23, 0x00, 0xd0])

                var randomData = Data(count: 208)
                Utils.Random.fill(data: &randomData)
                extData.append(randomData)

                extData.append(contentsOf: [0x00, 0x0d, 0x00, 0x16, 0x00, 0x14, 0x06, 0x01, 0x06, 0x03, 0x05, 0x01, 0x05, 0x03, 0x04, 0x01, 0x04, 0x03, 0x03, 0x01, 0x03, 0x03, 0x02, 0x01, 0x02, 0x03])
                extData.append(contentsOf: [0x00, 0x05, 0x00, 0x05, 0x01, 0x00, 0x00, 0x00, 0x00])
                extData.append(contentsOf: [0x00, 0x12, 0x00, 0x00])
                extData.append(contentsOf: [0x75, 0x50, 0x00, 0x00])
                extData.append(contentsOf: [0x00, 0x0b, 0x00, 0x02, 0x01, 0x00])
                extData.append(contentsOf: [0x00, 0x0a, 0x00, 0x06, 0x00, 0x04, 0x00, 0x17, 0x00, 0x18])

                _lenBE = UInt16(extData.count).bigEndian
                withUnsafeBytes(of: &_lenBE) {
                    outData.append($0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: $0.count)
                }
                outData.append(extData)

                var outputData = Data(capacity: outData.count + 9)
                outputData.append(contentsOf: [0x16, 0x03, 0x01])
                _lenBE = UInt16(outData.count + 4).bigEndian
                withUnsafeBytes(of: &_lenBE) {
                    outputData.append($0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: $0.count)
                }
                outputData.append(contentsOf: [0x01, 0x00])
                _lenBE = UInt16(outData.count).bigEndian
                withUnsafeBytes(of: &_lenBE) {
                    outputData.append($0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: $0.count)
                }
                outputData.append(outData)
                outputStreamProcessor.output(data: outputData)
            }

            private func handleStatus1(data: Data) {
                status = 8

                var outputData = Data()
                outputData.append(contentsOf: [0x14, 0x03, 0x03, 0x00, 0x01, 0x01, 0x16, 0x03, 0x03, 0x00, 0x20])
                var random = Data(count: 22)
                Utils.Random.fill(data: &random)
                outputData.append(random)

                var key = inputStreamProcessor.key
                key.append(clientID)
                outputData.withUnsafeBytes {
                    outputData.append(HMAC.final(value: $0.baseAddress!, length: outputData.count, algorithm: .SHA1, key: key).subdata(in: 0..<10))
                }

                outputData.append(pack(data: data))

                outputStreamProcessor.output(data: outputData)
            }

            private func handleInput(data: Data) throws {
                buffer.append(data: data)
                var unpackedData = Data()
                while buffer.left > 5 {
                    buffer.skip(3)
                    var length: Int = 0
                    buffer.withUnsafeBytes { (ptr: UnsafePointer<UInt16>) in
                        length = Int(ptr.pointee.byteSwapped)
                    }
                    buffer.skip(2)
                    if buffer.left >= length {
                        unpackedData.append(buffer.get(length: length)!)
                        continue
                    } else {
                        buffer.setBack(length: 5)
                        break
                    }
                }
                buffer.squeeze()
                try inputStreamProcessor.input(data: unpackedData)
            }
        }

    }
}
