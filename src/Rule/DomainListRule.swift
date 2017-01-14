import Foundation

/// The rule matches the host domain to a list of predefined criteria.
open class DomainListRule: Rule {
    public enum MatchCriterion {
        case regex(NSRegularExpression), prefix(String), suffix(String), keyword(String), complete(String)

        func match(_ domain: String) -> Bool {
            switch self {
            case .regex(let regex):
                return regex.firstMatch(in: domain, options: [], range: NSRange(location: 0, length: domain.utf8.count)) != nil
            case .prefix(let prefix):
                return domain.hasPrefix(prefix)
            case .suffix(let suffix):
                return domain.hasSuffix(suffix)
            case .keyword(let keyword):
                return domain.contains(keyword)
            case .complete(let match):
                return domain == match
            }
        }
    }

    fileprivate let adapterFactory: AdapterFactory

    open override var description: String {
        return "<DomainListRule>"
    }

    /// The list of criteria to match to.
    open var matchCriteria: [MatchCriterion] = []

    /**
     Create a new `DomainListRule` instance.

     - parameter adapterFactory: The factory which builds a corresponding adapter when needed.
     - parameter criteria:       The list of criteria to match.
     */
    public init(adapterFactory: AdapterFactory, criteria: [MatchCriterion]) {
        self.adapterFactory = adapterFactory
        self.matchCriteria = criteria
    }

    /**
     Match DNS request to this rule.

     - parameter session: The DNS session to match.
     - parameter type:    What kind of information is available.

     - returns: The result of match.
     */
    override open func matchDNS(_ session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        if matchDomain(session.requestMessage.queries.first!.name) {
            if let _ = adapterFactory as? DirectAdapterFactory {
                return .real
            }
            return .fake
        }
        return .pass
    }

    /**
     Match connect session to this rule.

     - parameter session: connect session to match.

     - returns: The configured adapter if matched, return `nil` if not matched.
     */
    override open func match(_ session: ConnectSession) -> AdapterFactory? {
        if matchDomain(session.host) {
            return adapterFactory
        }
        return nil
    }

    fileprivate func matchDomain(_ domain: String) -> Bool {
        for criterion in matchCriteria {
            if criterion.match(domain) {
                return true
            }
        }
        return false
    }
}
