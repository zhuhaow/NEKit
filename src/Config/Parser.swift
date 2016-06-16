import Foundation
import Yaml
import CocoaLumberjackSwift

public class Configuration {
    var adapterFactoryManager: AdapterFactoryManager!
    public var proxyPort: Int?
    public var ruleManager: RuleManager!

    public init() {}

    public func load(fromConfigString configString: String) -> Bool {
        let result = Yaml.load(configString)
        if let config = result.value {
            loadConfig(config)
            adapterFactoryManager = AdapterFactoryParser.parseAdapterFactoryManager(config["adapter"])
            ruleManager = RuleParser.parseRuleManager(config["rule"], adapterFactoryManager: adapterFactoryManager)
            return true
        } else {
            DDLogError("Failed to parse configuration: \(result.error!)")
            return false
        }
    }

    public func load(fromConfigFile filepath: String) -> Bool {
        do {
            let configString = try String(contentsOfFile: filepath)
            return load(fromConfigString: configString)

        } catch let e as NSError {
            DDLogError("Error when loading config file: \(e)")
            return false
        }
    }

    func loadConfig(config: Yaml) {
        if let port = config["port"].int {
            proxyPort = port
        }
    }

}
