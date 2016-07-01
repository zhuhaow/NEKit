import Foundation
import CocoaLumberjackSwift
import Yaml

struct AdapterFactoryParser {
    // swiftlint:disable:next cyclomatic_complexity
    static func parseAdapterFactoryManager(config: Yaml) -> AdapterFactoryManager {
        var factoryDict: [String: AdapterFactory] = [:]
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
            case .Some("ss"):
                guard let adapterFactory = parseShadowsocksAdapterFactory(adapterConfig) else {
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

    static func parseServerAdapterFactory(config: Yaml, type: AuthenticationAdapterFactory.Type) -> ServerAdapterFactory? {
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
        return type.init(serverHost: host, serverPort: port, auth: authentication)
    }

    static func parseShadowsocksAdapterFactory(config: Yaml) -> ShadowsocksAdapterFactory? {
        guard let host = config["host"].string else {
            DDLogError("Host is required.")
            return nil
        }

        guard let port = config["port"].int else {
            DDLogError("Port is required.")
            return nil
        }

        guard let encryptMethod = config["method"].string else {
            DDLogError("Shadowsocks adapter must define method.")
            return nil
        }

        guard let password = config["password"].string else {
            DDLogError("Shadowsocks adapter must define password.")
            return nil
        }

        return ShadowsocksAdapterFactory(serverHost: host, serverPort: port, encryptMethod: encryptMethod, password: password)
    }

    static func parseSpeedAdapterFactory(config: Yaml, factoryDict: [String:AdapterFactory]) -> SpeedAdapterFactory? {
        var factories: [(AdapterFactory, Int)] = []
        guard let adapters = config["adapters"].array else {
            DDLogError("Speed Adatper should specify a set of adapters.")
            return nil
        }
        for adapter in adapters {
            if let id = adapter["id"].string, delay = adapter["delay"].int {
                factories.append((factoryDict[id]!, delay))
            }
        }
        let adapter = SpeedAdapterFactory()
        adapter.adapterFactories = factories
        return adapter
    }
}
