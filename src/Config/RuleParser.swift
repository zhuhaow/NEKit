import Foundation
import Yaml

struct RuleParser {
    static func parseRuleManager(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> RuleManager {
        guard let ruleConfigs = config.array else {
            throw ConfigurationParserError.noRuleDefined
        }

        var rules: [Rule] = []

        for ruleConfig in ruleConfigs {
            rules.append(try parseRule(ruleConfig, adapterFactoryManager: adapterFactoryManager))
        }
        return RuleManager(fromRules: rules, appendDirect: true)
    }

    static func parseRule(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> Rule {
        guard let type = config["type"].string?.lowercased() else {
            throw ConfigurationParserError.ruleTypeMissing
        }

        switch type {
        case "country":
            return try parseCountryRule(config, adapterFactoryManager: adapterFactoryManager)
        case "all":
            return try parseAllRule(config, adapterFactoryManager: adapterFactoryManager)
        case "list", "domainlist":
            return try parseDomainListRule(config, adapterFactoryManager: adapterFactoryManager)
        case "iplist":
            return try parseIPRangeListRule(config, adapterFactoryManager: adapterFactoryManager)
        case "dnsfail":
            return try parseDNSFailRule(config, adapterFactoryManager: adapterFactoryManager)
        default:
            throw ConfigurationParserError.unknownRuleType
        }
    }

    static func parseCountryRule(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> CountryRule {
        guard let country = config["country"].string else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Country code (country) is required for country rule.")
        }

        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }

        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Unknown adapter id.")
        }

        guard let match = config["match"].bool else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "You have to specify whether to apply this rule to ip match the given country or not with \"match\".")
        }

        return CountryRule(countryCode: country, match: match, adapterFactory: adapter)
    }

    static func parseAllRule(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> AllRule {
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }

        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Unknown adapter id.")
        }

        return AllRule(adapterFactory: adapter)
    }

    static func parseDomainListRule(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> DomainListRule {
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }

        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Unknown adapter id.")
        }

        guard var filepath = config["file"].stringOrIntString else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Must provide a file (file) containing domain rules in list.")
        }

        filepath = (filepath as NSString).expandingTildeInPath

        do {
            let content = try String(contentsOfFile: filepath)
            let regexs = content.components(separatedBy: CharacterSet.newlines)
            var criteria: [DomainListRule.MatchCriterion] = []
            for regex in regexs {
                if !regex.isEmpty {
                    let re = try NSRegularExpression(pattern: regex, options: .caseInsensitive)
                    criteria.append(DomainListRule.MatchCriterion.regex(re))
                }
            }

            return DomainListRule(adapterFactory: adapter, criteria: criteria)
        } catch let error {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Encounter error when parse rule list file. \(error)")
        }
    }

    static func parseIPRangeListRule(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> IPRangeListRule {
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }

        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Unknown adapter id.")
        }

        guard var filepath = config["file"].stringOrIntString else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Must provide a file (file) containing IP range rules in list.")
        }

        filepath = (filepath as NSString).expandingTildeInPath

        do {
            let content = try String(contentsOfFile: filepath)
            var ranges = content.components(separatedBy: CharacterSet.newlines)
            ranges = ranges.filter {
                !$0.isEmpty
            }
            return try IPRangeListRule(adapterFactory: adapter, ranges: ranges)
        } catch let error {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Encounter error when parse IP range rule list file. \(error)")
        }
    }

    static func parseDNSFailRule(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> DNSFailRule {
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }

        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Unknown adapter id.")
        }

        return DNSFailRule(adapterFactory: adapter)
    }
}
