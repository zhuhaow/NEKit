import Foundation
import NetworkExtension

/**
 Represents the type of the socket.

 - NW:  The socket based on `NWTCPConnection`.
 - GCD: The socket based on `GCDAsyncSocket`.
 */
public enum SocketBaseType {
    case NW, GCD
}

/// Factory to create `RawTCPSocket` based on configuration.
public class RawSocketFactory {
    /// Current active `NETunnelProvider` which creates `NWTCPConnection` instance.
    ///
    /// - note: Must set before any connection is created if `NWTCPSocket` is used.
    public static weak var TunnelProvider: NETunnelProvider!

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
            if RawSocketFactory.TunnelProvider == nil {
                return GCDTCPSocket()
            } else {
                return NWTCPSocket()
            }
        }
    }
}
