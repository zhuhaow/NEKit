import Foundation
import CocoaLumberjackSwift

class CountryRule: Rule {
    let countryCode: String
    let match: Bool
    let adapterFactory: AdapterFactoryProtocol

    init(countryCode: String, match: Bool, adapterFactory: AdapterFactoryProtocol) {
        self.countryCode = countryCode
        self.match = match
        self.adapterFactory = adapterFactory
        super.init()
    }

    override func matchDNS(session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        guard type == .IP else {
            return .Unknown
        }

        if (session.countryCode != countryCode) != match {
            if let _ = adapterFactory as? DirectAdapterFactory {
                return .Real
            } else {
                return .Fake
            }
        }
        return .Pass
    }

    override func match(request: ConnectRequest) -> AdapterFactoryProtocol? {
        if (request.country != countryCode) != match {
            return adapterFactory
        }
        return nil
    }
}
