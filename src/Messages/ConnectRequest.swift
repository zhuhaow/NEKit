import Foundation

/// The request containing information to connect to remote.
public class ConnectRequest {
    /// The requested host.
    ///
    /// This is the host received in the request. May be a domain, a real IP or a fake IP.
    let requestedHost: String

    /// The real host for this request.
    ///
    /// If the request is initailized with a host domain, then `host == requestedHost`.
    /// Otherwise, the requested IP address is looked up in the DNS server to see if it corresponds to a domain if `fakeIPEnabled` is `true`.
    /// Unless there is a good reason not to, any socket shoule connect based on this directly.
    var host: String

    /// The requested port.
    let port: Int

    /// The rule to use to connect to remote.
    var matchedRule: Rule?

    /// Whether If the `requestedHost` is an IP address.
    let fakeIPEnabled: Bool

    /// The resolved IP address.
    ///
    /// - note: This will always be real IP address.
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

    /// The location of the host.
    lazy var country: String = {
        [unowned self] in
        Utils.GeoIPLookup.Lookup(self.ipAddress)
        }()

    init?(host: String, port: Int, fakeIPEnabled: Bool = true) {
        self.requestedHost = host
        self.port = port

        self.fakeIPEnabled = fakeIPEnabled

        self.host = host
        if fakeIPEnabled {
            guard lookupRealIP() else {
                return nil
            }
        }
    }

    convenience init?(ipAddress: IPv4Address, port: Port, fakeIPEnabled: Bool = true) {
        self.init(host: ipAddress.presentation, port: port.intValue, fakeIPEnabled: fakeIPEnabled)
    }

    private func lookupRealIP() -> Bool {
        /// If custom DNS server is set up.
        guard let dnsServer = DNSServer.currentServer else {
            return true
        }

        // Only IPv4 is supported as of now.
        guard isIPv4() else {
            return true
        }

        let address = IPv4Address(fromString: requestedHost)
        guard dnsServer.isFakeIP(address) else {
            return true
        }

        // Look up fake IP reversely should never fail.
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
        return "Request to: \(host):\(port) (\(requestedHost):\(port))"
    }
}
