import Foundation

/// The rule defines what to do for DNS requests and connect requests.
public class Rule: CustomStringConvertible {
    public var description: String {
        return "<Rule>"
    }

    /**
     Create a new rule.
     */
    public init() {
    }

    /**
     Match DNS request to this rule.

     - parameter session: The DNS session to match.
     - parameter type:    What kind of information is available.

     - returns: The result of match.
     */
    func matchDNS(session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        return .Real
    }

    /**
     Match connect request to this rule.

     - parameter request: Connect request to match.

     - returns: The configured adapter if matched, return `nil` if not matched.
     */
    func match(request: ConnectRequest) -> AdapterFactory? {
        return nil
    }
}
