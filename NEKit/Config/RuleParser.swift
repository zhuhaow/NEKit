import Foundation
import CocoaLumberjackSwift
import Yaml

struct RuleParser {
    static func parseRuleManager(config: Yaml, adapterFactoryManager: AdapterFactoryManager) -> RuleManager {
        guard let ruleConfigs = config.array else {
            DDLogError("No rules.")
            return RuleManager(fromRules: [], appendDirect: true)
        }
        var rules: [Rule] = []
        
        for ruleConfig in ruleConfigs {
            if let rule = parseRule(ruleConfig, adapterFactoryManager: adapterFactoryManager) {
                rules.append(rule)
            }
        }
        return RuleManager(fromRules: rules, appendDirect: true)
    }
    
    static func parseRule(config: Yaml, adapterFactoryManager: AdapterFactoryManager) -> Rule? {
        guard let type = config["type"].string?.lowercaseString else {
            DDLogError("Rule must have a type.")
            return nil
        }
        
        switch type {
        case "country":
            guard let country = config["country"].string else {
                DDLogError("Country rule requires country code.")
                return nil
            }
            
            guard let adapter_id = config["adapter"].string else {
                DDLogError("An adapter id is required.")
                return nil
            }
            
            guard let adapter = adapterFactoryManager[adapter_id] else {
                DDLogError("Unknown adapter id.")
                return nil
            }
            
            guard let match = config["match"].bool else {
                DDLogError("You have to specify whether to apply this rule to ip match the given country or not.")
                return nil
            }
            
            return CountryRule(countryCode: country, match: match, adapterFactory: adapter)
        case "all":
            guard let adapter_id = config["adapter"].string else {
                DDLogError("An adapter id is required.")
                return nil
            }
            
            guard let adapter = adapterFactoryManager[adapter_id] else {
                DDLogError("Unknown adapter id.")
                return nil
            }
            
            return AllRule(adapterFactory: adapter)
        case "list":
            guard let adapter_id = config["adapter"].string else {
                DDLogError("An adapter id is required.")
                return nil
            }
            
            guard let adapter = adapterFactoryManager[adapter_id] else {
                DDLogError("Unknown adapter id.")
                return nil
            }
            
            guard var filepath = config["file"].string else {
                DDLogError("Must provide a file")
                return nil
            }
            
            filepath = (filepath as NSString).stringByExpandingTildeInPath
            
            do {
                let content = try String(contentsOfFile: filepath)
                var urls = content.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
                if let url = urls.last {
                    if url == "" {
                        urls.removeLast()
                    }
                }
                return try ListRule(adapterFactory: adapter, urls: urls)
            } catch let error as NSError {
                DDLogError("\(error)")
                return nil
            }
        default:
            DDLogError("Unknown rule type.")
            return nil
        }
    }
    
}
