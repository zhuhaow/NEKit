import Foundation
import CocoaAsyncSocket
import CocoaLumberjackSwift

public class SOCKS5ProxyServer: ProxyServer, GCDAsyncSocketDelegate, TunnelDelegate {
    let listenQueue: dispatch_queue_t = dispatch_queue_create("me.zhuhaow.Specht.listenQueue", DISPATCH_QUEUE_SERIAL)
    var listenSocket : GCDAsyncSocket!
    var tunnels: [Tunnel] = []
    
    override public func start() -> Bool {
        listenSocket = GCDAsyncSocket(delegate: self, delegateQueue: listenQueue)
        do {
            try listenSocket.acceptOnInterface("127.0.0.1", port: UInt16(port))
            DDLogInfo("Successfully start SOCK5 proxy server on port \(port).")
            return true
        } catch let error as NSError {
            DDLogError("Failed to start SOCKS5 proxy server. \(error.localizedDescription)")
            return false
        }
    }
    
    override public func stop() {
        listenSocket.setDelegate(nil, delegateQueue: nil)
        listenSocket.disconnect()
        listenSocket = nil
        tunnels = []
    }
    
    public func socket(sock: GCDAsyncSocket!, didAcceptNewSocket newSocket: GCDAsyncSocket!) {
        DDLogVerbose("Proxy server accepted new socket.")
        let gcdSocket = GCDSocket(socket: newSocket)
        let proxySocket = SOCKS5ProxySocket(socket: gcdSocket)
        let tunnel = Tunnel(proxySocket: proxySocket)
        tunnel.delegate = self
        tunnels.append(tunnel)
        tunnel.openTunnel()
    }
    
    func tunnelDidClose(tunnel: Tunnel) {
        dispatch_async(listenQueue) {
            guard let index = self.tunnels.indexOf(tunnel) else {
                // things went strange
                DDLogError("Encountered an unknown tunnel.")
                return
            }
            self.tunnels.removeAtIndex(index)
            DDLogVerbose("Removed a closed tunnel, now there are \(self.tunnels.count) tunnels active.")
//            DDLogDebug("Active Tunnel Info:")
//            for tunnel in self.tunnels {
//                DDLogDebug("Tunnel to \(tunnel.proxySocket.request?.host), proxy socket state: \(tunnel.proxySocket.state), adapter socket state: \(tunnel.adapterSocket?.state), closed: \(tunnel.closed).")
//            }
        }
    }
}