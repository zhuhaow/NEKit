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
    
    public func load(fromConfigFile filepath: String) -> Bool{
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
            guard let type = config["type"].string else {
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
            default:
                DDLogError("Unknown rule type.")
                return nil
            }
        }
        
    }
    struct AdapterFactoryParser {
        static func parseAdapterFactoryManager(config :Yaml) -> AdapterFactoryManager {
            var factoryDict: [String: AdapterFactoryProtocol] = [:]
            factoryDict["direct"] = DirectAdapterFactory()
            guard let adapterConfigs = config.array else {
                DDLogWarn("Failed to parse adapter configuration or there is no adapter configuration.")
                return AdapterFactoryManager(factoryDict: factoryDict)
            }
            
            for adapterConfig in adapterConfigs {
                guard let id = adapterConfig["id"].string else {
                    DDLogError("Each adapter entry must have an id.")
                    continue
                }
                
                switch adapterConfig["type"].string?.lowercaseString {
                    //                case "SOCKS5":
                //                    factoryDict[id] = parseServerAdapterFactory(adapterConfig, type: SOCKS5AdapterFactory.self)
                case .Some("speed"):
                    guard let adapterFactory = parseSpeedAdapterFactory(adapterConfig, factoryDict: factoryDict) else {
                        DDLogError("Failed to parse adapter \(id).")
                        continue
                    }
                    factoryDict[id] = adapterFactory
                case .Some("http"):
                    guard let adapterFactory = parseServerAdapterFactory(adapterConfig, type: HTTPAdapterFactory.self) else {
                        DDLogError("Failed to parse adapter \(id).")
                        continue
                    }
                    factoryDict[id] = adapterFactory
                case .Some("shttp"):
                    guard let adapterFactory = parseServerAdapterFactory(adapterConfig, type: SecureHTTPAdapterFactory.self) else {
                        DDLogError("Failed to parse adapter \(id).")
                        continue
                    }
                    factoryDict[id] = adapterFactory
                case nil:
                    DDLogError("\(id) must have a type identifier. Ignored")
                    continue
                default:
                    DDLogError("\(id) has an unknown adapter type: \(adapterConfig["type"]). Ignored")
                    break
                }
                
            }
            return AdapterFactoryManager(factoryDict: factoryDict)
        }
        
        static func parseServerAdapterFactory(config :Yaml, type: AuthenticationAdapterFactory.Type) -> ServerAdapterFactory? {
            guard let host = config["host"].string else {
                DDLogError("Host is required.")
                return nil
            }
            
            guard let port = config["port"].int else {
                DDLogError("Port is required.")
                return nil
            }
            
            var authentication: Authentication? = nil
            if let auth = config["auth"].bool {
                if auth {
                    guard let username = config["username"].string else {
                        DDLogError("Username is required.")
                        return nil
                    }
                    guard let password = config["password"].string else {
                        DDLogError("Password is required.")
                        return nil
                    }
                    authentication = Authentication(username: username, password: password)
                }
            }
            return type.init(host: host, port: port, auth: authentication)
        }
        
        static func parseSpeedAdapterFactory(config: Yaml, factoryDict: [String:AdapterFactoryProtocol]) -> SpeedAdapterFactory? {
            var factories: [AdapterFactoryProtocol] = []
            guard let adapterIDs = config["adapter"].array else {
                DDLogError("Speed Adatper should specify a set of adapters.")
                return nil
            }
            for id in adapterIDs {
                if let id = id.string {
                    factories.append(factoryDict[id]!)
                }
            }
            let adapter = SpeedAdapterFactory()
            adapter.adapterFactories = factories
            return adapter
        }
    }
}
