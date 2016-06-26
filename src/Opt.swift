import Foundation

struct Opt {
    static let MAXNWTCPSocketReadDataSize = 15000

    // This is only used in finding the end of HTTP header (as of now). There is no limit on the length of http header, but Apache set it to 8KB
    static let MAXNWTCPScanLength = 8912

    static let DNSFakeIPTTL = 300
}
