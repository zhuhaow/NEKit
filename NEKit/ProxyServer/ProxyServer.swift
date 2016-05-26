import Foundation
import CocoaAsyncSocket
import CocoaLumberjackSwift

public class ProxyServer: NSObject, TunnelDelegate {
    public static var currentProxy: ProxyServer!
    let port: Int
    let address: String
    var tunnels: [Tunnel] = []

    public init(address: String, port: Int) {
        self.address = address
        self.port = port
    }

    public func start() -> Bool {
        return true
    }

    public func stop() {
        tunnels = []
    }

    func didAcceptNewSocket(socket: ProxySocket) {
        let tunnel = Tunnel(proxySocket: socket)
        tunnel.delegate = self
        tunnels.append(tunnel)
        tunnel.openTunnel()
    }

    // must be called in the same dispatch_queue as the `didAcceptNewSocket`
    func tunnelDidClose(tunnel: Tunnel) {
        guard let index = tunnels.indexOf(tunnel) else {
            // things went strange
            DDLogError("Encountered an unknown tunnel.")
            return
        }
        tunnels.removeAtIndex(index)
        DDLogVerbose("Removed a closed tunnel, now there are \(tunnels.count) tunnels active.")
        //            DDLogDebug("Active Tunnel Info:")
        //            for tunnel in self.tunnels {
        //                DDLogDebug("Tunnel to \(tunnel.proxySocket.request?.host), proxy socket state: \(tunnel.proxySocket.state), adapter socket state: \(tunnel.adapterSocket?.state), closed: \(tunnel.closed).")
        //
    }

    public func inQueue(block: ()->()) {

    }
}
