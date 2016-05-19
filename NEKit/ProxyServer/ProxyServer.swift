import Foundation
import CocoaAsyncSocket

public class ProxyServer: NSObject {
    public static var currentProxy: ProxyServer!
    let port: Int
    let address: String

    public init(address: String, port: Int) {
        self.address = address
        self.port = port
    }

    public func start() -> Bool {
        return false
    }

    public func stop() {

    }
}
