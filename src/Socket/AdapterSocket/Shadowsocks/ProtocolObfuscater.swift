import Foundation

extension ShadowsocksAdapter {
    public struct ProtocolObfuscater {
        public class Factory {
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

                    var outputData = generateHeader(encapsulating: data.subdata(in: 0..<fakeRequestDataLength)).data(using: .utf8)!
                    outputData.append(data.subdata(in: fakeRequestDataLength..<data.count))
                    sendHeader = true
                    outputStreamProcessor.output(data: outputData)
                }
            }
        }
    }
}
