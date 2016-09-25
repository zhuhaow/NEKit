import Foundation

/// The rule matches the host domain to a list of predefined criteria.
public class DomainListRule: Rule {
    public enum MatchCriterion {
        case Regex(NSRegularExpression), Prefix(String), Suffix(String), Keyword(String)
        
        func match(domain: String) -> Bool {
            switch self {
            case .Regex(let regex):
                return regex.firstMatchInString(domain, options: [], range: NSRange(location: 0, length: domain.utf8.count)) != nil
            case .Prefix(let prefix):
                return domain.hasPrefix(prefix)
            case .Suffix(let suffix):
                return domain.hasSuffix(suffix)
            case .Keyword(let keyword):
                return domain.containsString(keyword)
            }
        }
    }
    
    private let adapterFactory: AdapterFactory

    public override var description: String {
        return "<DomainListRule>"
    }

    /// The list of criteria to match to.
    public var matchCriteria: [MatchCriterion] = []

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
    override func matchDNS(session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        if matchDomain(session.requestMessage.queries.first!.name) {
            if let _ = adapterFactory as? DirectAdapterFactory {
                return .Real
            }
            return .Fake
        }
        return .Pass
    }

    /**
     Match connect request to this rule.

     - parameter request: Connect request to match.

     - returns: The configured adapter if matched, return `nil` if not matched.
     */
    override func match(request: ConnectRequest) -> AdapterFactory? {
        if matchDomain(request.host) {
            return adapterFactory
        }
        return nil
    }

    private func matchDomain(domain: String) -> Bool {
        for criterion in matchCriteria {
            if criterion.match(domain) {
                return true
            }
        }
        return false
    }
}
