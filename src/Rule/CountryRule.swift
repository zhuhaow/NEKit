import Foundation
import CocoaLumberjackSwift

/// The rule matches the request based on the geographical location of the corresponding IP address.
open class CountryRule: Rule {
    fileprivate let adapterFactory: AdapterFactory

    /// The ISO code of the country.
    open let countryCode: String

    /// The rule should match the request which matches the country or not.
    open let match: Bool

    open override var description: String {
        return "<CountryRule countryCode:\(countryCode) match:\(match)>"
    }

    /**
     Create a new `CountryRule` instance.

     - parameter countryCode:    The ISO code of the country.
     - parameter match:          The rule should match the request which matches the country or not.
     - parameter adapterFactory: The factory which builds a corresponding adapter when needed.
     */
    public init(countryCode: String, match: Bool, adapterFactory: AdapterFactory) {
        self.countryCode = countryCode
        self.match = match
        self.adapterFactory = adapterFactory
        super.init()
    }

    /**
     Match DNS request to this rule.

     - parameter session: The DNS session to match.
     - parameter type:    What kind of information is available.

     - returns: The result of match.
     */
    override func matchDNS(_ session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        guard type == .ip else {
            return .unknown
        }

        if (session.countryCode != countryCode) != match {
            if let _ = adapterFactory as? DirectAdapterFactory {
                return .real
            } else {
                return .fake
            }
        }
        return .pass
    }

    /**
     Match connect request to this rule.

     - parameter request: Connect request to match.

     - returns: The configured adapter if matched, return `nil` if not matched.
     */
    override func match(_ request: ConnectRequest) -> AdapterFactory? {
        if (request.country != countryCode) != match {
            return adapterFactory
        }
        return nil
    }
}
