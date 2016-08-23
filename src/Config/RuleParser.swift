import Foundation
import Yaml

struct RuleParser {
    static func parseRuleManager(config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> RuleManager {
        guard let ruleConfigs = config.array else {
            throw ConfigurationParserError.NoRuleDefined
        }

        var rules: [Rule] = []

        for ruleConfig in ruleConfigs {
            rules.append(try parseRule(ruleConfig, adapterFactoryManager: adapterFactoryManager))
        }
        return RuleManager(fromRules: rules, appendDirect: true)
    }

    static func parseRule(config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> Rule {
        guard let type = config["type"].string?.lowercaseString else {
            throw ConfigurationParserError.RuleTypeMissing
        }

        switch type {
        case "country":
            return try parseCountryRule(config, adapterFactoryManager: adapterFactoryManager)
        case "all":
            return try parseAllRule(config, adapterFactoryManager: adapterFactoryManager)
        case "list", "domainlist":
            return try parseDomainListRule(config, adapterFactoryManager: adapterFactoryManager)
        case "iprange":
            return try parseIPRangeListRule(config, adapterFactoryManager: adapterFactoryManager)
        case "dnsfail":
            return try parseDNSFailRule(config, adapterFactoryManager: adapterFactoryManager)
        default:
            throw ConfigurationParserError.UnknownRuleType
        }
    }

    static func parseCountryRule(config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> CountryRule {
        guard let country = config["country"].string else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "Country code (country) is required for country rule.")
        }

        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }

        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "Unknown adapter id.")
        }

        guard let match = config["match"].bool else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "You have to specify whether to apply this rule to ip match the given country or not with \"match\".")
        }

        return CountryRule(countryCode: country, match: match, adapterFactory: adapter)
    }

    static func parseAllRule(config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> AllRule {
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }

        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "Unknown adapter id.")
        }

        return AllRule(adapterFactory: adapter)
    }

    static func parseDomainListRule(config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> DomainListRule {
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }

        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "Unknown adapter id.")
        }

        guard var filepath = config["file"].stringOrIntString else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "Must provide a file (file) containing domain rules in list.")
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
            return try DomainListRule(adapterFactory: adapter, urls: urls)
        } catch let error {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "Encounter error when parse rule list file. \(error)")
        }
    }

    static func parseIPRangeListRule(config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> IPRangeListRule {
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }

        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "Unknown adapter id.")
        }

        guard var filepath = config["file"].stringOrIntString else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "Must provide a file (file) containing IP range rules in list.")
        }

        filepath = (filepath as NSString).stringByExpandingTildeInPath

        do {
            let content = try String(contentsOfFile: filepath)
            var ranges = content.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
            if let range = ranges.last {
                if range == "" {
                    ranges.removeLast()
                }
            }
            return try IPRangeListRule(adapterFactory: adapter, ranges: ranges)
        } catch let error {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "Encounter error when parse IP range rule list file. \(error)")
        }
    }

    static func parseDNSFailRule(config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> DNSFailRule {
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }

        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.RuleParsingError(errorInfo: "Unknown adapter id.")
        }

        return DNSFailRule(adapterFactory: adapter)
    }
}
