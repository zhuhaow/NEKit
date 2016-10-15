import Foundation

public struct Utils {
    public struct HTTPData {
        public static let DoubleCRLF = "\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!
        public static let CRLF = "\r\n".dataUsingEncoding(NSUTF8StringEncoding)!
        public static let ConnectSuccessResponse = "HTTP/1.1 200 Connection Established\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!
    }

    public struct DNS {
        // swiftlint:disable:next nesting
        public enum QueryType {
            // swiftlint:disable:next type_name
            case A, AAAA, UNSPEC
        }

        public static func resolve(name: String, type: QueryType = .UNSPEC) -> String {
            let remoteHostEnt = gethostbyname2((name as NSString).UTF8String, AF_INET)

            if remoteHostEnt == nil {
                return ""
            }

            let remoteAddr = UnsafeMutablePointer<Void>(remoteHostEnt.memory.h_addr_list[0])

            var output = [Int8](count: Int(INET6_ADDRSTRLEN), repeatedValue: 0)
            inet_ntop(AF_INET, remoteAddr, &output, socklen_t(INET6_ADDRSTRLEN))
            return NSString(UTF8String: output)! as String
        }
    }

    // swiftlint:disable:next type_name
    public struct IP {
        public static func isIPv4(ipAddress: String) -> Bool {
            if IPv4ToInt(ipAddress) != nil {
                return true
            } else {
                return false
            }
        }

        public static func isIPv6(ipAddress: String) -> Bool {
            let utf8Str = (ipAddress as NSString).UTF8String
            var dst = [UInt8](count: 16, repeatedValue: 0)
            return inet_pton(AF_INET6, utf8Str, &dst) == 1
        }

        public static func isIP(ipAddress: String) -> Bool {
            return isIPv4(ipAddress) || isIPv6(ipAddress)
        }

        public static func IPv4ToInt(ipAddress: String) -> UInt32? {
            let utf8Str = (ipAddress as NSString).UTF8String
            var dst = in_addr(s_addr: 0)
            if inet_pton(AF_INET, utf8Str, &(dst.s_addr)) == 1 {
                return UInt32(dst.s_addr)
            } else {
                return nil
            }
        }

        public static func IPv4ToBytes(ipAddress: String) -> [UInt8]? {
            if let ipv4int = IPv4ToInt(ipAddress) {
                return Utils.toByteArray(ipv4int).reverse()
            } else {
                return nil
            }
        }

        public static func IPv6ToBytes(ipAddress: String) -> [UInt8]? {
            let utf8Str = (ipAddress as NSString).UTF8String
            var dst = [UInt8](count: 16, repeatedValue: 0)
            if inet_pton(AF_INET6, utf8Str, &dst) == 1 {
                return Utils.toByteArray(dst).reverse()
            } else {
                return nil
            }
        }
    }

    struct GeoIPLookup {

        static func Lookup(ipAddress: String) -> String? {
            if Utils.IP.isIP(ipAddress) {
                guard let result = GeoIP.LookUp(ipAddress) else {
                    return "--"
                }
                return result.isoCode
            } else {
                return nil
            }
        }
    }

    static func toByteArray<T>(value: T) -> [UInt8] {
        var value = value
        return withUnsafePointer(&value) {
            Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(T)))
        }
    }
}
