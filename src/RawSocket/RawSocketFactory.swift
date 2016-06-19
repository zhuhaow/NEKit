import Foundation

/**
 Represents the type of the socket.

 - NW:  The socket based on `NWTCPConnection`.
 - GCD: The socket based on `GCDAsyncSocket`.
 */
enum SocketBaseType {
    case NW, GCD
}

/// Factory to create `RawTCPSocket` based on configuration.
class RawSocketFactory {
    /**
     Return `RawTCPSocket` instance.

     - parameter type: The type of the socket.

     - returns: The created socket instance.
     */
    static func getRawSocket(type: SocketBaseType? = nil) -> RawTCPSocketProtocol {
        switch type {
        case .Some(.NW):
            return NWTCPSocket()
        case .Some(.GCD):
            return GCDTCPSocket()
        case nil:
            if NetworkInterface.TunnelProvider == nil {
                return GCDTCPSocket()
            } else {
                return NWTCPSocket()
            }
        }
    }
}
