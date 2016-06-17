import Foundation

class RawSocketFactory {
    static func getRawSocket() -> RawTCPSocketProtocol {
        if NetworkInterface.TunnelProvider == nil {
            return GCDTCPSocket()
        } else {
            return NWTCPSocket()
        }
    }
}
