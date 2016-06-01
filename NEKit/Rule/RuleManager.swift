import Foundation
import CocoaLumberjackSwift

public class RuleManager {
    public static var currentManager: RuleManager = RuleManager(fromRules: [], appendDirect: true)

    var rules: [Rule] = []

    init(fromRules rules: [Rule], appendDirect: Bool = false) {
        self.rules = rules

        if appendDirect || self.rules.count == 0 {
            self.rules.append(DirectRule())
        }
    }

    func matchDNS(session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        for rule in rules {
            let result = rule.matchDNS(session, type: type)
            switch result {
            case .Fake, .Real, .Unknown:
                session.matchedRule = rule
                return result
            case .Pass:
                break
            }
        }
        return .Real
    }

    func match(request: ConnectRequest) -> AdapterFactoryProtocol! {
        for rule in rules {
            if let adapterFactory = rule.match(request) {
                DDLogVerbose("Rule \(rule) matches request: \(request)")
                return adapterFactory
            } else {
                DDLogVerbose("Rule \(rule) does not match request: \(request)")
            }
        }
        return nil // this should never happens
    }
}
