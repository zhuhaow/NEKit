import Foundation

/// The class managing rules.
public class RuleManager {
    /// The current used `RuleManager`, there is only one manager should be used at a time.
    ///
    /// - note: This should be set before any DNS or connect requests.
    public static var currentManager: RuleManager = RuleManager(fromRules: [], appendDirect: true)

    /// The rule list.
    var rules: [Rule] = []

    public var observer: Observer<RuleMatchEvent>?

    /**
     Create a new `RuleManager` from the given rules.

     - parameter rules:        The rules.
     - parameter appendDirect: Whether to append a `DirectRule` at the end of the list so any request does not match with any rule go directly.
     */
    public init(fromRules rules: [Rule], appendDirect: Bool = false) {
        self.rules = rules

        if appendDirect || self.rules.count == 0 {
            self.rules.append(DirectRule())
        }

        observer = ObserverFactory.currentFactory?.getObserverForRuleManager(self)
    }

    /**
     Match DNS request to all rules.

     - parameter session: The DNS session to match.
     - parameter type:    What kind of information is available.
     */
    func matchDNS(session: DNSSession, type: DNSSessionMatchType) {
        for (i, rule) in rules[session.indexToMatch..<rules.count].enumerate() {
            let result = rule.matchDNS(session, type: type)

            observer?.signal(.DNSRuleMatched(session, rule: rule, type: type, result: result))

            switch result {
            case .Fake, .Real, .Unknown:
                session.matchedRule = rule
                session.matchResult = result
                session.indexToMatch = i + session.indexToMatch // add the offset
                return
            case .Pass:
                break
            }
        }
    }

    /**
     Match connect request to all rules.

     - parameter request: Connect request to match.

     - returns: The matched configured adapter.
     */
    func match(request: ConnectRequest) -> AdapterFactory! {
        if request.matchedRule != nil {
            observer?.signal(.RuleMatched(request, rule: request.matchedRule!))
            return request.matchedRule!.match(request)
        }

        for rule in rules {
            if let adapterFactory = rule.match(request) {
                observer?.signal(.RuleMatched(request, rule: rule))

                request.matchedRule = rule
                return adapterFactory
            } else {
                observer?.signal(.RuleDidNotMatch(request, rule: rule))
            }
        }
        return nil // this should never happens
    }
}
