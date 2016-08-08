import Foundation

/// The rule matches the request which failed to look up.
public class DNSFailRule: Rule {
    private let adapterFactory: AdapterFactory

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
    override func matchDNS(session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        guard type == .IP else {
            return .Unknown
        }

        // only return real IP when we connect to remote directly
        if session.realIP == nil {
            if let _ = adapterFactory as? DirectAdapterFactory {
                return .Real
            } else {
                return .Fake
            }
        } else {
            return .Pass
        }
    }

    /**
     Match connect request to this rule.

     - parameter request: Connect request to match.

     - returns: The configured adapter.
     */
    override func match(request: ConnectRequest) -> AdapterFactory? {
        if request.ipAddress == "" {
            return adapterFactory
        } else {
            return nil
        }
    }
}
