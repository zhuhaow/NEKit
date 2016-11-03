import Foundation

public enum RuleMatchEvent: EventType {
    public var description: String {
        switch self {
        case let .ruleMatched(request, rule: rule):
            return "Rule \(rule) matched request \(request)."
        case let .ruleDidNotMatch(request, rule: rule):
            return "Rule \(rule) did not match request \(request)."
        case let .dnsRuleMatched(session, rule: rule, type: type, result: result):
            return "Rule \(rule) matched DNS session \(session) of type \(type), the result is \(result)."
        }
    }

    case ruleMatched(ConnectRequest, rule: Rule), ruleDidNotMatch(ConnectRequest, rule: Rule), dnsRuleMatched(DNSSession, rule: Rule, type: DNSSessionMatchType, result: DNSSessionMatchResult)
}
