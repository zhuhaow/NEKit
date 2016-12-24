import Foundation

public struct Opt {
    public static var MAXNWTCPSocketReadDataSize = 128 * 1024

    // This is only used in finding the end of HTTP header (as of now). There is no limit on the length of http header, but Apache set it to 8KB
    public static var MAXNWTCPScanLength = 8912

    public static var DNSFakeIPTTL = 300

    public static var DNSPendingSessionLifeTime = 10

    public static var UDPSocketActiveTimeout = 300

    public static var UDPSocketActiveCheckInterval = 60

    public static var MAXHTTPContentBlockLength = 10240

    public static var RejectAdapterDefaultDelay = 300

    public static var DNSTimeout = 1

    public static var forwardReadInterval = 50
}
