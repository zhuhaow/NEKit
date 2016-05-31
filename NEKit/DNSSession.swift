import Foundation

class DNSSession {
    let name: String
    var realIP: IPv4Address?
    var fakeIP: IPv4Address?
    var realDNSResponse: NSData?
    var requestData: NSData?
    var matchedRule: Rule?
    var expireAt: NSDate?
    lazy var countryCode: String? = {
        [unowned self] in
        guard self.realIP != nil else {
            return nil
        }
        return Utils.GeoIPLookup.Lookup(self.realIP!.presentation)
    }()

    init(name: String) {
        self.name = name
    }
}
