import Foundation
import tun2socks
import CocoaLumberjackSwift

public class IPStack: IPStackDelegate {
    public init() {}

    public func start() {
        TUNIPStack.stack.delegate = self
        TUNIPStack.stack.tunInterface = TunInterface()
        TUNIPStack.stack.startProcessing()
    }

    public func didAcceptTCPSocket(sock: TSTCPSocket) {
        DDLogDebug("Accepted a new socket from IP stack.")
        let tunSocket = TUNTCPSocket(socket: sock)
        let proxySocket = DirectProxySocket(socket: tunSocket)
        ProxyServer.currentProxy.didAcceptNewSocket(proxySocket)
    }
}
