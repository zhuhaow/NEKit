import Foundation

public class RuleManager {
    public static var currentManager: RuleManager = RuleManager(fromRules: [], appendDirect: true)
    
    var rules :[Rule] = []
    
    init(fromRules rules: [Rule], appendDirect: Bool = false) {
        self.rules = rules
        
        if appendDirect || self.rules.count == 0 {
            self.rules.append(DirectRule())
        }
    }
    
    func match(request :ConnectRequest) -> AdapterFactoryProtocol! {
        for rule in rules {
            if let adapterFactory = rule.match(request) {
                return adapterFactory
            }
        }
        return nil // this should never happens
    }
}