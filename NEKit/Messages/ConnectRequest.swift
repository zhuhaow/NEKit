import Foundation
class ConnectRequest : NSObject {
    enum Method : Int {
        case HTTP_CONNECT, HTTP_DIRECT, SOCKS5
    }
    
    let host :String
    let port :UInt16
    let method :Method
    lazy var IP :String = {
        [unowned self] in
        if self.isIP() {
            return self.host
        } else {
            return Utils.DNS.resolve(self.host)
        }
    }()
    lazy var country: String = {
        [unowned self] in
        Utils.GeoIPLookup.Lookup(self.IP)
    }()
    var httpProxyRawHeader :NSData?
    var removeHTTPProxyHeader = true
    var rewritePath = true
    
    
    init(host: String, port: UInt16, method: Method) {
        self.host = host
        self.port = port
        self.method = method
    }
    
    convenience init(host: String, port: Int, method: Method) {
        self.init(host: host, port: UInt16(port), method: method)
    }
    
    //    subscript(index: String) -> Any? {
    //        get { return auxiliaries[index] }
    //        set { auxiliaries[index] = newValue }
    //    }
    
    func _getIP() -> String {
        if isIP() {
            return host
        } else {
            return Utils.DNS.resolve(host)
        }
    }
    
    func isIPv4() -> Bool {
        return Utils.IP.isIPv4(self.host)
    }
    
    func isIPv6() -> Bool {
        return Utils.IP.isIPv6(self.host)
    }
    
    func isIP() -> Bool {
        return isIPv4() || isIPv6()
    }
}

class ConnectResponse : NSObject {}