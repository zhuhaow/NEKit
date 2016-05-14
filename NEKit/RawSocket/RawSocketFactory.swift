import Foundation

class RawSocketFactory {
    static func getRawSocket() -> RawSocketProtocol {
//        return GCDSocket()
        return NWTCPSocket()
    }
}
