import Foundation
import CocoaLumberjackSwift

class DNSSession {
    let requestMessage: DNSMessage
    var realIP: IPv4Address?
    var fakeIP: IPv4Address?
    var realDNSResponse: NSData?
    var matchedRule: Rule?
    var matchResult: DNSSessionMatchResult?
    var indexToMatch = 0
    var expireAt: NSDate?
    lazy var countryCode: String? = {
        [unowned self] in
        guard self.realIP != nil else {
            return nil
        }
        return Utils.GeoIPLookup.Lookup(self.realIP!.presentation)
    }()

    init?(message: DNSMessage) {
        guard message.messageType == .Query else {
            DDLogError("DNSSession can only be initailized by a DNS query.")
            return nil
        }

        guard message.queries.count == 1 else {
            DDLogError("Expecting the DNS query has exact one query entry.")
            return nil
        }

        self.requestMessage = message
    }
}
