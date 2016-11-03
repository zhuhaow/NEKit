import Foundation
import NetworkExtension

/**
 Represents the type of the socket.

 - NW:  The socket based on `NWTCPConnection`.
 - GCD: The socket based on `GCDAsyncSocket`.
 */
public enum SocketBaseType {
    case nw, gcd
}

/// Factory to create `RawTCPSocket` based on configuration.
open class RawSocketFactory {
    /// Current active `NETunnelProvider` which creates `NWTCPConnection` instance.
    ///
    /// - note: Must set before any connection is created if `NWTCPSocket` or `NWUDPSocket` is used.
    open static weak var TunnelProvider: NETunnelProvider?

    /**
     Return `RawTCPSocket` instance.

     - parameter type: The type of the socket.

     - returns: The created socket instance.
     */
    open static func getRawSocket(_ type: SocketBaseType? = nil) -> RawTCPSocketProtocol {
        switch type {
        case .some(.nw):
            return NWTCPSocket()
        case .some(.gcd):
            return GCDTCPSocket()
        case nil:
            if RawSocketFactory.TunnelProvider == nil {
                return GCDTCPSocket()
            } else {
                return NWTCPSocket()
            }
        }
    }
}
