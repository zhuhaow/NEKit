import Foundation

public enum RuleMatchEvent: EventType {
    public var description: String {
        switch self {
        case let .RuleMatched(request, rule: rule):
            return "Rule \(rule) matched request \(request)."
        case let .RuleDidNotMatch(request, rule: rule):
            return "Rule \(rule) did not match request \(request)."
        case let .DNSRuleMatched(session, rule: rule, type: type, result: result):
            return "Rule \(rule) matched DNS session \(session) of type \(type), the result is \(result)."
        }
    }

    case RuleMatched(ConnectRequest, rule: Rule), RuleDidNotMatch(ConnectRequest, rule: Rule), DNSRuleMatched(DNSSession, rule: Rule, type: DNSSessionMatchType, result: DNSSessionMatchResult)
}
