import Foundation
import tun2socks
import CocoaLumberjackSwift

class TCPStack: TSIPStackDelegate, IPStackProtocol {
    var outputFunc: (([NSData], [NSNumber]) -> ())! {
        get {
            return TSIPStack.stack.outputBlock
        }
        set {
            TSIPStack.stack.outputBlock = newValue
        }
    }

    init() {
        TSIPStack.stack.delegate = self
    }

    func inputPacket(packet: NSData, version: NSNumber?) -> Bool {
        if let version = version {
            // we do not process IPv6 packets now
            if version.intValue == AF_INET6 {
                return false
            }
        }
        if IPPacket.peekTransportType(packet) == .Some(.TCP) {
            TSIPStack.stack.receivedPacket(packet)
            return true
        }
        return false
    }

    func didAcceptTCPSocket(sock: TSTCPSocket) {
        DDLogDebug("Accepted a new socket from IP stack.")
        let tunSocket = TUNTCPSocket(socket: sock)
        let proxySocket = DirectProxySocket(socket: tunSocket)
        ProxyServer.currentProxy.didAcceptNewSocket(proxySocket)
    }
}
