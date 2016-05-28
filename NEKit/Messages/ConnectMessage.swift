import Foundation
class ConnectRequest {
    let host: String
    let port: Int

    lazy var ipAddress: String = {
        [unowned self] in
        if self.isIP() {
            return self.host
        } else {
            return Utils.DNS.resolve(self.host)
        }
    }()
    lazy var country: String = {
        [unowned self] in
        Utils.GeoIPLookup.Lookup(self.ipAddress)
    }()


    init(host: String, port: Int) {
        self.host = host
        self.port = port
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

extension ConnectRequest: CustomStringConvertible {
    var description: String {
        return "Request to: \(host):\(port)"
    }
}

class ConnectResponse {}
