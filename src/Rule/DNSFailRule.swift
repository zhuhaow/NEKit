import Foundation

/// The rule matches the request which failed to look up.
open class DNSFailRule: Rule {
    fileprivate let adapterFactory: AdapterFactory

    open override var description: String {
        return "<DNSFailRule>"
    }

    /**
     Create a new `DNSFailRule` instance.

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
    override open func matchDNS(_ session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        guard type == .ip else {
            return .unknown
        }

        // only return real IP when we connect to remote directly
        if session.realIP == nil {
            if let _ = adapterFactory as? DirectAdapterFactory {
                return .real
            } else {
                return .fake
            }
        } else {
            return .pass
        }
    }

    /**
     Match connect session to this rule.

     - parameter session: connect session to match.

     - returns: The configured adapter.
     */
    override open func match(_ session: ConnectSession) -> AdapterFactory? {
        if session.ipAddress == "" {
            return adapterFactory
        } else {
            return nil
        }
    }
}
