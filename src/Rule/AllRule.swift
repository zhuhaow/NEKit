import Foundation

/// The rule matches all DNS and connect sessions.
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
     Match DNS session to this rule.

     - parameter session: The DNS session to match.
     - parameter type:    What kind of information is available.

     - returns: The result of match.
     */
    override open func matchDNS(_ session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        // only return real IP when we connect to remote directly
        if let _ = adapterFactory as? DirectAdapterFactory {
            return .real
        } else {
            return .fake
        }
    }

    /**
     Match connect session to this rule.

     - parameter session: connect session to match.

     - returns: The configured adapter.
     */
    override open func match(_ session: ConnectSession) -> AdapterFactory? {
        return adapterFactory
    }
}
