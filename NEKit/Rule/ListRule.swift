import Foundation

class ListRule: Rule {
    var urls: [NSRegularExpression] = []
    let adapterFactory: AdapterFactoryProtocol

    init(adapterFactory: AdapterFactoryProtocol, urls: [String]) throws {
        self.adapterFactory = adapterFactory
        self.urls = try urls.map {
            try NSRegularExpression(pattern: $0, options: .CaseInsensitive)
        }
    }

    override func matchDNS(session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        if matchDomain(session.name) {
            if let _ = adapterFactory as? DirectAdapterFactory {
                return .Real
            }
            return .Fake
        }
        return .Pass
    }

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
