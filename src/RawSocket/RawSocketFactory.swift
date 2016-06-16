import Foundation

class RawSocketFactory {
    static func getRawSocket() -> RawSocketProtocol {
        if NetworkInterface.TunnelProvider == nil {
            return GCDTCPSocket()
        } else {
            return NWTCPSocket()
        }
    }
}
