import Foundation
import tun2socks
import CocoaLumberjackSwift

/// This class wraps around tun2socks to build a TCP only IP stack.
public class TCPStack: TSIPStackDelegate, IPStackProtocol {
    /// This is set automatically when the stack is registered to some interface.
    public var outputFunc: (([NSData], [NSNumber]) -> ())! {
        get {
            return TSIPStack.stack.outputBlock
        }
        set {
            TSIPStack.stack.outputBlock = newValue
        }
    }

    /**
     Inistailize a new TCP stack.
     */
    public init() {
        TSIPStack.stack.delegate = self
    }

    /**
     Input a packet into the stack.

     - note: Only process IPv4 TCP packet as of now, since stable lwip does not support ipv6 yet.

     - parameter packet:  The IP packet.
     - parameter version: The version of the IP packet, i.e., AF_INET, AF_INET6.

     - returns: If the stack takes in this packet. If the packet is taken in, then it won't be processed by other IP stacks.
     */
    public func inputPacket(packet: NSData, version: NSNumber?) -> Bool {
        if let version = version {
            // we do not process IPv6 packets now
            if version.intValue == AF_INET6 {
                return false
            }
        }
        if IPPacket.peekTransportType(packet) == .TCP {
            TSIPStack.stack.receivedPacket(packet)
            return true
        }
        return false
    }

    // MARK: TSIPStackDelegate Implemention
    public func didAcceptTCPSocket(sock: TSTCPSocket) {
        DDLogDebug("Accepted a new socket from IP stack.")
        let tunSocket = TUNTCPSocket(socket: sock)
        let proxySocket = DirectProxySocket(socket: tunSocket)
        ProxyServer.mainProxy.didAcceptNewSocket(proxySocket)
    }
}
