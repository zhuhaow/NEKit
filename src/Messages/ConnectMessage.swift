import Foundation
public class ConnectRequest {
    var host: String
    var port: Int
    var matchedRule: Rule?

    lazy var ipAddress: String = {
        [unowned self] in
        if self.isIP() {
            return self.host
        } else {
            let ip = Utils.DNS.resolve(self.host)
            guard let dnsServer = DNSServer.currentServer else {
                return ip
            }

            let address = IPv4Address(fromString: ip)
            guard dnsServer.isFakeIP(address) else {
                return ip
            }

            guard let session = dnsServer.lookupFakeIP(address) else {
                return ip
            }

            return session.realIP!.presentation
        }
    }()

    lazy var country: String = {
        [unowned self] in
        Utils.GeoIPLookup.Lookup(self.ipAddress)
    }()


    init?(host: String, port: Int) {
        self.host = host
        self.port = port

        guard let dnsServer = DNSServer.currentServer else {
            return
        }

        guard isIPv4() else {
            return
        }

        let address = IPv4Address(fromString: self.host)
        guard dnsServer.isFakeIP(address) else {
            return
        }

        guard let session = dnsServer.lookupFakeIP(address) else {
            return nil
        }

        self.host = session.requestMessage.queries[0].name
        ipAddress = session.realIP!.presentation
        matchedRule = session.matchedRule

        if session.countryCode != nil {
            country = session.countryCode!
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

extension ConnectRequest: CustomStringConvertible {
    public var description: String {
        return "Request to: \(host):\(port)"
    }
}

class ConnectResponse {}
