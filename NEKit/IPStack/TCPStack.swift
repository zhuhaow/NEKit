import Foundation
import tun2socks
import CocoaLumberjackSwift

public class TCPStack: TSIPStackDelegate, IPStackProtocol {
    public var outputFunc: (([NSData], [NSNumber]) -> ())! {
        get {
            return TSIPStack.stack.outputBlock
        }
        set {
            TSIPStack.stack.outputBlock = newValue
        }
    }

    public init() {
        TSIPStack.stack.delegate = self
    }

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

    public func didAcceptTCPSocket(sock: TSTCPSocket) {
        DDLogDebug("Accepted a new socket from IP stack.")
        let tunSocket = TUNTCPSocket(socket: sock)
        let proxySocket = DirectProxySocket(socket: tunSocket)
        ProxyServer.currentProxy.didAcceptNewSocket(proxySocket)
    }
}
