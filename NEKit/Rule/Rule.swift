import Foundation

enum DNSSessionMatchResult {
    case Real, Fake, Unknown, Pass
}

enum DNSSessionMatchType {
    // swiftlint:disable:next type_name
    case Domain, IP
}

class Rule {
    let name: String?

    init() {
        name = nil
    }

    func matchDNS(session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        return .Real
    }

    func match(request: ConnectRequest) -> AdapterFactoryProtocol? {
        return nil
    }
}

class AllRule: Rule {
    let adapterFactory: AdapterFactoryProtocol

    init(adapterFactory: AdapterFactoryProtocol) {
        self.adapterFactory = adapterFactory
        super.init()
    }

    override func matchDNS(session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        // only return real IP when we connect to remote directly
        if let _ = adapterFactory as? DirectAdapterFactory {
            return .Real
        } else {
            return .Fake
        }
    }

    override func match(request: ConnectRequest) -> AdapterFactoryProtocol? {
        return adapterFactory
    }
}

class DirectRule: AllRule {
    init() {
        super.init(adapterFactory: DirectAdapterFactory())
    }
}
