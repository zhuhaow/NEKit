import Foundation
import CocoaAsyncSocket

public class ProxyServer : NSObject {
    static var currentProxy : ProxyServer!
    let port: Int
    
    public init(port: Int) {
        self.port = port
    }
    
    public func start() -> Bool {
        return false
    }
    
    public func stop() {
        
    }
}