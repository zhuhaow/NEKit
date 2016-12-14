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
            class Factory: ProtocolObfuscater.Factory {
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
    }
}
