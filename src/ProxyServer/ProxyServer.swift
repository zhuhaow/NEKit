import Foundation
import CocoaAsyncSocket
import CocoaLumberjackSwift

/**
 The base proxy server class.

 This proxy does not listen on any port.
 */
public class ProxyServer: NSObject, TunnelDelegate {
    typealias TunnelPool = Atomic<[Tunnel]>

    /// The main proxy.
    ///
    /// There can be arbitrary number of proxies running at the same time. However, it is assumed that there is a main proxy server that handles connections that do not target any proxies but still should be proxied.
    ///
    /// - warning: This must be set before any connection is created.
    public static var mainProxy: ProxyServer!

    /// The port of proxy server.
    public let port: Int

    /// The address of proxy server.
    public let address: String

    private var tunnelPool: TunnelPool = Atomic([])

    /**
     Create an instance of proxy server.

     - parameter address: The address of proxy server.
     - parameter port:    The port of proxy server.
     */
    public init(address: String, port: Int) {
        self.address = address
        self.port = port
    }

    /**
     Start the proxy server.

     - returns: If the proxy starts successfully.
     */
    public func start() -> Bool {
        return true
    }

    /**
     Stop the proxy server.
     */
    public func stop() {
        tunnelPool.value.removeAll(keepCapacity: true)
    }

    /**
     Delegate method when the proxy server accepts a new ProxySocket from local.

     When implementing a concrete proxy server, e.g., HTTP proxy server, the server should listen on some port and then wrap the raw socket in a corresponding ProxySocket subclass, then call this method.

     - parameter socket: The accepted proxy socket.
     */
    func didAcceptNewSocket(socket: ProxySocket) {
        let tunnel = Tunnel(proxySocket: socket)
        tunnel.delegate = self
        tunnelPool.value.append(tunnel)
        tunnel.openTunnel()
    }

    // MARK: TunnelDelegate implemention

    /**
     Delegate method when a tunnel closed. The server will remote it internally.

     - parameter tunnel: The closed tunnel.
     */
    func tunnelDidClose(tunnel: Tunnel) {
        tunnelPool.withBox { tunnels in
            guard let index = tunnels.value.indexOf(tunnel) else {
                // things went strange
                DDLogError("Encountered an unknown tunnel.")
                return
            }
            tunnels.value.removeAtIndex(index)
            DDLogVerbose("Removed a closed tunnel, now there are \(tunnels.value.count) tunnels active.")
            //            DDLogDebug("Active Tunnel Info:")
            //            for tunnel in self.tunnels {
            //                DDLogDebug("Tunnel to \(tunnel.proxySocket.request?.host), proxy socket state: \(tunnel.proxySocket.state), adapter socket state: \(tunnel.adapterSocket?.state), closed: \(tunnel.closed).")
            //
        }
    }
}
