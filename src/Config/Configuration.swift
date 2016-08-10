import Foundation
import Yaml

public enum ConfigurationParserError: ErrorType {
    case InvalidYamlFile, NoRuleDefined, RuleTypeMissing, UnknownRuleType, RuleParsingError(errorInfo: String), NoAdapterDefined, AdapterIDMissing, AdapterTypeMissing, AdapterTypeUnknown, AdapterParsingError(errorInfo: String)
}

/// The configuration file parser.
///
/// Note: It is not recommended to use this class in production app. This is merely used as a helper to build a toy app.
public class Configuration {
    var adapterFactoryManager: AdapterFactoryManager!
    public var proxyPort: Int?
    public var ruleManager: RuleManager!

    public init() {}

    public func load(fromConfigString configString: String) throws {
        let result = Yaml.load(configString)
        if let config = result.value {
            loadConfig(config)
            adapterFactoryManager = try AdapterFactoryParser.parseAdapterFactoryManager(config["adapter"])
            ruleManager = try RuleParser.parseRuleManager(config["rule"], adapterFactoryManager: adapterFactoryManager)
        } else {
            throw ConfigurationParserError.InvalidYamlFile
        }
    }

    public func load(fromConfigFile filepath: String) throws {
        let configString = try String(contentsOfFile: filepath)
        try load(fromConfigString: configString)
    }

    func loadConfig(config: Yaml) {
        if let port = config["port"].int {
            proxyPort = port
        }
    }

}
