import Foundation

/// The rule matches all DNS and connect requests.
open class AllRule: Rule {
    fileprivate let adapterFactory: AdapterFactory

    open override var description: String {
        return "<AllRule>"
    }

    /**
     Create a new `AllRule` instance.

     - parameter adapterFactory: The factory which builds a corresponding adapter when needed.
     */
    public init(adapterFactory: AdapterFactory) {
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
        // only return real IP when we connect to remote directly
        if let _ = adapterFactory as? DirectAdapterFactory {
            return .real
        } else {
            return .fake
        }
    }

    /**
     Match connect request to this rule.

     - parameter request: Connect request to match.

     - returns: The configured adapter.
     */
    override func match(_ request: ConnectRequest) -> AdapterFactory? {
        return adapterFactory
    }
}
