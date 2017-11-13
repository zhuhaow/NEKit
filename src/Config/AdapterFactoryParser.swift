import Foundation
import Yaml

struct AdapterFactoryParser {
    // swiftlint:disable:next cyclomatic_complexity
    static func parseAdapterFactoryManager(_ config: Yaml) throws -> AdapterFactoryManager {
        var factoryDict: [String: AdapterFactory] = [:]
        factoryDict["direct"] = DirectAdapterFactory()
        guard let adapterConfigs = config.array else {
            throw ConfigurationParserError.noAdapterDefined
        }

        for adapterConfig in adapterConfigs {
            guard let id = adapterConfig["id"].stringOrIntString else {
                throw ConfigurationParserError.adapterIDMissing
            }

            switch adapterConfig["type"].string?.lowercased() {
            case .some("speed"):
                factoryDict[id] = try parseSpeedAdapterFactory(adapterConfig, factoryDict: factoryDict)
            case .some("http"):
                factoryDict[id] = try parseServerAdapterFactory(adapterConfig, type: HTTPAdapterFactory.self)
            case .some("shttp"):
                factoryDict[id] = try parseServerAdapterFactory(adapterConfig, type: SecureHTTPAdapterFactory.self)
            case .some("ss"):
                factoryDict[id] = try parseShadowsocksAdapterFactory(adapterConfig)
            case .some("socks5"):
                factoryDict[id] = try parseSOCKS5AdapterFactory(adapterConfig)
            case .some("reject"):
                factoryDict[id] = try parseRejectAdapterFactory(adapterConfig)
            case nil:
                throw ConfigurationParserError.adapterTypeMissing
            default:
                throw ConfigurationParserError.adapterTypeUnknown
            }

        }
        return AdapterFactoryManager(factoryDict: factoryDict)
    }

    static func parseServerAdapterFactory(_ config: Yaml, type: HTTPAuthenticationAdapterFactory.Type) throws -> ServerAdapterFactory {
        guard let host = config["host"].string else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Host (host) is required.")
        }

        guard let port = config["port"].int else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Port (port) is required.")
        }

        var authentication: HTTPAuthentication? = nil
        if let auth = config["auth"].bool {
            if auth {
                guard let username = config["username"].stringOrIntString else {
                    throw ConfigurationParserError.adapterParsingError(errorInfo: "Username (username) is required.")
                }
                guard let password = config["password"].stringOrIntString else {
                    throw ConfigurationParserError.adapterParsingError(errorInfo: "Password (password) is required.")
                }
                authentication = HTTPAuthentication(username: username, password: password)
            }
        }
        return type.init(serverHost: host, serverPort: port, auth: authentication)
    }

    static func parseSOCKS5AdapterFactory(_ config: Yaml) throws -> SOCKS5AdapterFactory {
        guard let host = config["host"].string else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Host (host) is required.")
        }

        guard let port = config["port"].int else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Port (port) is required.")
        }

        return SOCKS5AdapterFactory(serverHost: host, serverPort: port)
    }

    static func parseShadowsocksAdapterFactory(_ config: Yaml) throws -> ShadowsocksAdapterFactory {
        guard let host = config["host"].string else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Host (host) is required.")
        }

        guard let port = config["port"].int else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Port (port) is required.")
        }

        guard let encryptMethod = config["method"].string else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Encryption method (method) is required.")
        }

        guard let algorithm = CryptoAlgorithm(rawValue: encryptMethod.uppercased()) else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Encryption method \(encryptMethod) is not supported.")
        }

        guard let password = config["password"].stringOrIntString else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Password (password) is required.")
        }

        if let _ = config["ota"].string {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Do not use \"ota: true\", use \"protocol: verify_sha1\" instead.")
        }

        let proto = config["obfs"].string?.lowercased() ?? "origin"
        let stream = config["protocol"].string?.lowercased() ?? "origin"

        let protocolObfuscaterFactory: ShadowsocksAdapter.ProtocolObfuscater.Factory
        switch proto {
        case "origin":
            protocolObfuscaterFactory = ShadowsocksAdapter.ProtocolObfuscater.OriginProtocolObfuscater.Factory()
        case "http_simple":
            var headerHosts = [host]
            var customHeader: String?
            let headerMethod = "GET"

            if let param = config["obfs_param"].string {
                let params = param.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: true)
                if params.count > 0 {
                    headerHosts = String(params[0]).components(separatedBy: ",")
                    if params.count > 1 {
                        customHeader = String(params[1])
                        customHeader = customHeader?.replacingOccurrences(of: "\n", with: "\r\n")
                        customHeader = customHeader?.replacingOccurrences(of: "\\n", with: "\r\n")
                    }
                }
            }
            protocolObfuscaterFactory = ShadowsocksAdapter.ProtocolObfuscater.HTTPProtocolObfuscater.Factory(method: headerMethod, hosts: headerHosts, customHeader: customHeader)
        case "tls1.2_ticket_auth":
            var headerHosts = [host]

            if let param = config["obfs_param"].string {
                    headerHosts = String(param).components(separatedBy: ",")
            }
            protocolObfuscaterFactory = ShadowsocksAdapter.ProtocolObfuscater.TLSProtocolObfuscater.Factory(hosts: headerHosts)
        default:
            throw ConfigurationParserError.adapterParsingError(errorInfo: "obfs \"\(proto)\" is not supported")
        }

        let streamObfuscaterFactory: ShadowsocksAdapter.StreamObfuscater.Factory
        switch stream {
        case "origin":
            streamObfuscaterFactory = ShadowsocksAdapter.StreamObfuscater.OriginStreamObfuscater.Factory()
        case "verify_sha1":
            streamObfuscaterFactory = ShadowsocksAdapter.StreamObfuscater.OTAStreamObfuscater.Factory()
        default:
            throw ConfigurationParserError.adapterParsingError(errorInfo: "protocol \"\(stream)\" is not supported")
        }

        let cryptoFactory = ShadowsocksAdapter.CryptoStreamProcessor.Factory(password: password, algorithm: algorithm)

        return ShadowsocksAdapterFactory(serverHost: host, serverPort: port, protocolObfuscaterFactory: protocolObfuscaterFactory, cryptorFactory: cryptoFactory, streamObfuscaterFactory: streamObfuscaterFactory)
    }

    static func parseSpeedAdapterFactory(_ config: Yaml, factoryDict: [String:AdapterFactory]) throws -> SpeedAdapterFactory {
        var factories: [(AdapterFactory, Int)] = []
        guard let adapters = config["adapters"].array else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Speed Adatper should specify a set of adapters (adapters).")
        }
        for adapter in adapters {
            guard let id = adapter["id"].string else {
                throw ConfigurationParserError.adapterParsingError(errorInfo: "An adapter id (adapter_id) is required.")
            }
            guard let factory = factoryDict[id] else {
                throw ConfigurationParserError.adapterParsingError(errorInfo: "Unknown adapter id.")
            }
            guard let delay = adapter["delay"].int else {
                throw ConfigurationParserError.adapterParsingError(errorInfo: "Each adapter in Speed Adapter must specify a delay in millisecond.")
            }

            factories.append((factory, delay))
        }
        let adapter = SpeedAdapterFactory()
        adapter.adapterFactories = factories
        return adapter
    }

    static func parseRejectAdapterFactory(_ config: Yaml) throws -> RejectAdapterFactory {

        guard let delay = config["delay"].int else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Reject adapter must specify a delay in millisecond.")
        }

        return RejectAdapterFactory(delay: delay)
    }
}
