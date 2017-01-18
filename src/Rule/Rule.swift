import Foundation

/// The rule defines what to do for DNS requests and connect sessions.
open class Rule: CustomStringConvertible {
    open var description: String {
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
    open func matchDNS(_ session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        return .real
    }

    /**
     Match connect session to this rule.

     - parameter session: connect session to match.

     - returns: The configured adapter if matched, return `nil` if not matched.
     */
    open func match(_ session: ConnectSession) -> AdapterFactory? {
        return nil
    }
}
