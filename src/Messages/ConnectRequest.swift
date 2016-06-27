import Foundation

/// The request containing information to connect to remote.
public class ConnectRequest {
    var host: String
    var port: Int
    var matchedRule: Rule?
    let fakeIPEnabled: Bool

    lazy var ipAddress: String = {
        [unowned self] in
        if self.isIP() {
            return self.host
        } else {
            let ip = Utils.DNS.resolve(self.host)

            guard self.fakeIPEnabled else {
                return ip
            }

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


    init?(host: String, port: Int, fakeIPEnabled: Bool = false) {
        self.host = host
        self.port = port

        self.fakeIPEnabled = fakeIPEnabled

        if fakeIPEnabled {
            guard lookupRealIP() else {
                return nil
            }
        }
    }

    private func lookupRealIP() -> Bool {
        guard let dnsServer = DNSServer.currentServer else {
            return true
        }

        guard isIPv4() else {
            return true
        }

        let address = IPv4Address(fromString: host)
        guard dnsServer.isFakeIP(address) else {
            return true
        }

        guard let session = dnsServer.lookupFakeIP(address) else {
            return false
        }

        host = session.requestMessage.queries[0].name
        ipAddress = session.realIP!.presentation
        matchedRule = session.matchedRule

        if session.countryCode != nil {
            country = session.countryCode!
        }
        return true
    }

    func isIPv4() -> Bool {
        return Utils.IP.isIPv4(host)
    }

    func isIPv6() -> Bool {
        return Utils.IP.isIPv6(host)
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
