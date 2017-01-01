import Foundation

open class ResponseGeneratorFactory {
    static var HTTPProxyResponseGenerator: ResponseGenerator.Type?
    static var SOCKS5ProxyResponseGenerator: ResponseGenerator.Type?
}
