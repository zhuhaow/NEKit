import Foundation

public enum RuleMatchEvent: EventType {
    public var description: String {
        switch self {
        case let .ruleMatched(session, rule: rule):
            return "Rule \(rule) matched session \(session)."
        case let .ruleDidNotMatch(session, rule: rule):
            return "Rule \(rule) did not match session \(session)."
        case let .dnsRuleMatched(session, rule: rule, type: type, result: result):
            return "Rule \(rule) matched DNS session \(session) of type \(type), the result is \(result)."
        }
    }

    case ruleMatched(ConnectSession, rule: Rule), ruleDidNotMatch(ConnectSession, rule: Rule), dnsRuleMatched(DNSSession, rule: Rule, type: DNSSessionMatchType, result: DNSSessionMatchResult)
}
