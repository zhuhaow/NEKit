import Foundation

/// The rule matches the host domain to a list of predefined regular expressions.
class ListRule: Rule {
    private let adapterFactory: AdapterFactoryProtocol

    /// The list of regular expressions to match to.
    var urls: [NSRegularExpression] = []

    /**
     Create a new `ListRule` instance.

     - parameter adapterFactory: The factory which builds a corresponding adapter when needed.
     - parameter urls:           The list of regular expressions to match. The regular expression is parsed by `NSRegularExpression(pattern: url, options: .CaseInsensitive)`.

     - throws: The error when parsing the regualar expressions.
     */
    init(adapterFactory: AdapterFactoryProtocol, urls: [String]) throws {
        self.adapterFactory = adapterFactory
        self.urls = try urls.map {
            try NSRegularExpression(pattern: $0, options: .CaseInsensitive)
        }
    }

    /**
     Match DNS request to this rule.

     - parameter session: The DNS session to match.
     - parameter type:    What kind of information is available.

     - returns: The result of match.
     */
    override func matchDNS(session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        if matchDomain(session.requestMessage.queries.first!.name) {
            if let _ = adapterFactory as? DirectAdapterFactory {
                return .Real
            }
            return .Fake
        }
        return .Pass
    }

    /**
     Match connect request to this rule.

     - parameter request: Connect request to match.

     - returns: The configured adapter if matched, return `nil` if not matched.
     */
    override func match(request: ConnectRequest) -> AdapterFactoryProtocol? {
        if matchDomain(request.host) {
            return adapterFactory
        }
        return nil
    }

    private func matchDomain(name: String) -> Bool {
        for url in urls {
            if let _ = url.firstMatchInString(name, options: [], range: NSRange(location: 0, length: name.utf16.count)) {
                return true
            }
        }
        return false
    }
}
