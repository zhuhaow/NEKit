import Foundation

struct Opt {
    static let MAXNWTCPSocketReadDataSize = 15000

    // This is only used in finding the end of HTTP header (as of now). There is no limit on the length of http header, but Apache set it to 8KB
    static let MAXNWTCPScanLength = 8912

    static let DNSFakeIPTTL = 300

    static let DNSPendingSessionLifeTime = 10

    static let UDPSocketActiveTimeout = 300

    static let UDPSocketActiveCheckInterval = 60

    static let MAXHTTPContentBlockLength = 10240
}
