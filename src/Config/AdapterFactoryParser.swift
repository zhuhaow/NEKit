import Foundation
import Yaml

struct AdapterFactoryParser {
    // swiftlint:disable:next cyclomatic_complexity
    static func parseAdapterFactoryManager(config: Yaml) throws -> AdapterFactoryManager {
        var factoryDict: [String: AdapterFactory] = [:]
        factoryDict["direct"] = DirectAdapterFactory()
        guard let adapterConfigs = config.array else {
            throw ConfigurationParserError.NoAdapterDefined
        }

        for adapterConfig in adapterConfigs {
            guard let id = adapterConfig["id"].string else {
                throw ConfigurationParserError.AdapterIDMissing
            }

            switch adapterConfig["type"].string?.lowercaseString {
            case .Some("speed"):
                factoryDict[id] = try parseSpeedAdapterFactory(adapterConfig, factoryDict: factoryDict)
            case .Some("http"):
                factoryDict[id] = try parseServerAdapterFactory(adapterConfig, type: HTTPAdapterFactory.self)
            case .Some("shttp"):
                factoryDict[id] = try parseServerAdapterFactory(adapterConfig, type: SecureHTTPAdapterFactory.self)
            case .Some("ss"):
                factoryDict[id] = try parseShadowsocksAdapterFactory(adapterConfig)
            case nil:
                throw ConfigurationParserError.AdapterTypeMissing
            default:
                throw ConfigurationParserError.AdapterTypeUnknown
            }

        }
        return AdapterFactoryManager(factoryDict: factoryDict)
    }

    static func parseServerAdapterFactory(config: Yaml, type: HTTPAuthenticationAdapterFactory.Type) throws -> ServerAdapterFactory {
        guard let host = config["host"].string else {
            throw ConfigurationParserError.AdapterParsingError(errorInfo: "Host (host) is required.")
        }

        guard let port = config["port"].int else {
            throw ConfigurationParserError.AdapterParsingError(errorInfo: "Port (port) is required.")
        }

        var authentication: HTTPAuthentication? = nil
        if let auth = config["auth"].bool {
            if auth {
                guard let username = config["username"].string else {
                    throw ConfigurationParserError.AdapterParsingError(errorInfo: "Username (username) is required.")
                }
                guard let password = config["password"].string else {
                    throw ConfigurationParserError.AdapterParsingError(errorInfo: "Password (password) is required.")
                }
                authentication = HTTPAuthentication(username: username, password: password)
            }
        }
        return type.init(serverHost: host, serverPort: port, auth: authentication)
    }

    static func parseShadowsocksAdapterFactory(config: Yaml) throws -> ShadowsocksAdapterFactory {
        guard let host = config["host"].string else {
            throw ConfigurationParserError.AdapterParsingError(errorInfo: "Host (host) is required.")
        }

        guard let port = config["port"].int else {
            throw ConfigurationParserError.AdapterParsingError(errorInfo: "Port (port) is required.")
        }

        guard let encryptMethod = config["method"].string else {
            throw ConfigurationParserError.AdapterParsingError(errorInfo: "Encryption method (method) is required.")
        }

        guard let password = config["password"].string else {
            throw ConfigurationParserError.AdapterParsingError(errorInfo: "Password (password) is required.")
        }

        return ShadowsocksAdapterFactory(serverHost: host, serverPort: port, encryptAlgorithm: encryptMethod, password: password)!
    }

    static func parseSpeedAdapterFactory(config: Yaml, factoryDict: [String:AdapterFactory]) throws -> SpeedAdapterFactory {
        var factories: [(AdapterFactory, Int)] = []
        guard let adapters = config["adapters"].array else {
            throw ConfigurationParserError.AdapterParsingError(errorInfo: "Speed Adatper should specify a set of adapters (adapters).")
        }
        for adapter in adapters {
            guard let id = adapter["id"].string else {
                throw ConfigurationParserError.AdapterParsingError(errorInfo: "An adapter id (adapter_id) is required.")
            }
            guard let factory = factoryDict[id] else {
                throw ConfigurationParserError.AdapterParsingError(errorInfo: "Unknown adapter id.")
            }
            guard let delay = adapter["delay"].int else {
                throw ConfigurationParserError.AdapterParsingError(errorInfo: "Each adapter in Speed Adapter must specify a delay in millisecond.")
            }

            factories.append((factory, delay))
        }
        let adapter = SpeedAdapterFactory()
        adapter.adapterFactories = factories
        return adapter
    }
}
