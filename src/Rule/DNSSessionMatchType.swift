import Foundation

/**
 The information available in current round of matching.

 Since we want to speed things up, we first match the request without resolving it (`.Domain`). If any rule returns `.Unknown`, we lookup the request and rematches that rule (`.IP`).

 - Domain: Only domain information is available.
 - IP:     The IP address is resolved.
 */
public enum DNSSessionMatchType {
    case domain, ip
}
