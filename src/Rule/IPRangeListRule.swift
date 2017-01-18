import Foundation

/// The rule matches the ip of the target hsot to a list of IP ranges.
open class IPRangeListRule: Rule {
    fileprivate let adapterFactory: AdapterFactory

    open override var description: String {
        return "<IPRangeList>"
    }

    /// The list of regular expressions to match to.
    open var ranges: [IPRange] = []

    /**
     Create a new `IPRangeListRule` instance.

     - parameter adapterFactory: The factory which builds a corresponding adapter when needed.
     - parameter ranges:           The list of IP ranges to match. The IP ranges are expressed in CIDR form ("127.0.0.1/8") or range form ("127.0.0.1+16777216").

     - throws: The error when parsing the IP range.
     */
    public init(adapterFactory: AdapterFactory, ranges: [String]) throws {
        self.adapterFactory = adapterFactory
        self.ranges = try ranges.map {
            let range = try IPRange(withString: $0)
            return range
        }
    }

    /**
     Match DNS request to this rule.

     - parameter session: The DNS session to match.
     - parameter type:    What kind of information is available.

     - returns: The result of match.
     */
    override open func matchDNS(_ session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        guard type == .ip else {
            return .unknown
        }

        // Probably we should match all answers?
        guard let ip = session.realIP else {
            return .pass
        }

        for range in ranges {
            if range.contains(ip: ip) {
                return .fake
            }
        }
        return .pass
    }

    /**
     Match connect session to this rule.

     - parameter session: connect session to match.

     - returns: The configured adapter if matched, return `nil` if not matched.
     */
    override open func match(_ session: ConnectSession) -> AdapterFactory? {
        guard let ip = IPAddress(fromString: session.ipAddress) else {
            return nil
        }

        for range in ranges {
            if range.contains(ip: ip) {
                return adapterFactory
            }
        }
        return nil
    }
}
