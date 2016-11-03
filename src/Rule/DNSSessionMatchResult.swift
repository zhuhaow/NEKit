import Foundation

/**
 The result of matching the rule to DNS request.

 - Real:    The request matches the rule and the connection can be done with a real IP address.
 - Fake:    The request matches the rule but we need to identify this session when a later connection is fired with an IP address instead of the host domain.
 - Unknown: The match type is `DNSSessionMatchType.Domain` but rule needs the resolved IP address.
 - Pass:    This rule does not match the request.
 */
public enum DNSSessionMatchResult {
    case real, fake, unknown, pass
}
