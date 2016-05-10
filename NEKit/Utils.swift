import Foundation
 import CommonCrypto

struct Utils {
    struct HTTPData {
        static let DoubleCRLF = "\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!
        static let CRLF = "\r\n".dataUsingEncoding(NSUTF8StringEncoding)!
        static let ConnectSuccessResponse = "HTTP/1.1 200 Connection Established\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!
    }
    
    struct DNS {
        enum QueryType {
            case A, AAAA, UNSPEC
        }
        
        static func resolve(name: String, type: QueryType = .UNSPEC) -> String {
            let remoteHostEnt = gethostbyname2((name as NSString).UTF8String, AF_INET)
            
            if remoteHostEnt == nil {
                return ""
            }
            
            let remoteAddr = UnsafeMutablePointer<in_addr>(remoteHostEnt.memory.h_addr_list[0]).memory
            
            let addr = inet_ntoa(remoteAddr)
            return NSString(UTF8String: addr)! as String
        }
    }
    
    struct IP {
        static func isIPv4(ip: String) -> Bool {
            if IPv4ToInt(ip) != nil {
                return true
            } else {
                return false
            }
        }
        
        static func isIPv6(ip: String) -> Bool {
            let utf8Str = (ip as NSString).UTF8String
            var dst = [UInt8](count: 16, repeatedValue: 0)
            return inet_pton(AF_INET6, utf8Str, &dst) == 1
        }
        
        static func isIP(ip: String) -> Bool {
            return isIPv4(ip) || isIPv6(ip)
        }
        
        static func IPv4ToInt(ip: String) -> UInt32? {
            let utf8Str = (ip as NSString).UTF8String
            var dst = in_addr(s_addr: 0)
            if inet_pton(AF_INET, utf8Str, &(dst.s_addr)) == 1 {
                return UInt32(dst.s_addr)
            } else {
                return nil
            }
        }
        
        static func IPv4ToBytes(ip: String) -> [UInt8]? {
            if let ipv4int = IPv4ToInt(ip) {
                return Utils.toByteArray(ipv4int).reverse()
            } else {
                return nil
            }
        }
        
        static func IPv6ToBytes(ip: String) -> [UInt8]? {
            let utf8Str = (ip as NSString).UTF8String
            var dst = [UInt8](count: 16, repeatedValue: 0)
            if inet_pton(AF_INET6, utf8Str, &dst) == 1 {
                return Utils.toByteArray(dst).reverse()
            } else {
                return nil
            }
        }
    }
    
    struct GeoIPLookup {
//        static var _geoIPLookup : GeoIP {
//            struct holder {
//                static let geoIP = GeoIP(database: NSBundle.mainBundle().pathForResource("GeoIP", ofType: "dat"))
//            }
//            return holder.geoIP
//        }
        
        static func Lookup(ip: String) -> String {
            if Utils.IP.isIPv4(ip) {
                guard let result = GeoIP.LookUp(ip) else {
                    return "--"
                }
                return result.isoCode
            } else {
                return "--"
            }
        }
    }
    
    struct Crypto {
        static func MD5(value: String) -> NSData {
            let data = value.dataUsingEncoding(NSUTF8StringEncoding)!
            return MD5(data)
        }
        
        static func MD5(value: NSData) -> NSData {
            let result = NSMutableData(length: Int(CC_MD5_DIGEST_LENGTH))!
            CC_MD5(value.bytes, CC_LONG(value.length), UnsafeMutablePointer<UInt8>(result.mutableBytes))
            return NSData(data: result)
        }
    }

    static func toByteArray<T>(value: T) -> [UInt8] {
        var value = value
        return withUnsafePointer(&value) {
            Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(T)))
        }
    }
}