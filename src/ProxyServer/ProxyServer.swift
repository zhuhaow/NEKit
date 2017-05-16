import Foundation
import CocoaAsyncSocket
import Resolver

/**
 The base proxy server class.
 
 This proxy does not listen on any port.
 */
open class ProxyServer: NSObject, TunnelDelegate {
    typealias TunnelArray = [Tunnel]

    /// The port of proxy server.
    open let port: Port

    /// The address of proxy server.
    open let address: IPAddress?

    /// The type of the proxy server.
    ///
    /// This can be set to anything describing the proxy server.
    open let type: String

    /// The description of proxy server.
    open override var description: String {
        return "<\(type) address:\(address) port:\(port)>"
    }

    open var observer: Observer<ProxyServerEvent>?

    var tunnels: TunnelArray = []
    
    private let accessQueue = DispatchQueue(label: "NEKit.ProxyServer.TunnelArrayAccess", attributes: .concurrent)

    /**
     Create an instance of proxy server.
     
     - parameter address: The address of proxy server.
     - parameter port:    The port of proxy server.
     
     - warning: If you are using Network Extension, you have to set address or you may not able to connect to the proxy server.
     */
    public init(address: IPAddress?, port: Port) {
        self.address = address
        self.port = port
        type = "\(type(of: self))"

        super.init()

        self.observer = ObserverFactory.currentFactory?.getObserverForProxyServer(self)
    }

    /**
     Start the proxy server.
     
     - throws: The error occured when starting the proxy server.
     */
    open func start() throws {
        QueueFactory.executeOnQueueSynchronizedly {
            GlobalIntializer.initalize()
            self.observer?.signal(.started(self))
        }
    }

    /**
     Stop the proxy server.
     */
    open func stop() {
        QueueFactory.executeOnQueueSynchronizedly {
            for tunnel in tunnels {
                tunnel.forceClose()
            }

            observer?.signal(.stopped(self))
        }
    }

    /**
     Delegate method when the proxy server accepts a new ProxySocket from local.
     
     When implementing a concrete proxy server, e.g., HTTP proxy server, the server should listen on some port and then wrap the raw socket in a corresponding ProxySocket subclass, then call this method.
     
     - parameter socket: The accepted proxy socket.
     */
    func didAcceptNewSocket(_ socket: ProxySocket) {
        observer?.signal(.newSocketAccepted(socket, onServer: self))
        
        let tunnel = Tunnel(proxySocket: socket)
        tunnel.delegate = self
        
        self.accessQueue.async(flags: .barrier) {
            self.tunnels.append(tunnel)
        }
        
        tunnel.openTunnel()
    }

    // MARK: TunnelDelegate implementation

    /**
     Delegate method when a tunnel closed. The server will remote it internally.
     
     - parameter tunnel: The closed tunnel.
     */
    func tunnelDidClose(_ tunnel: Tunnel) {
        observer?.signal(.tunnelClosed(tunnel, onServer: self))
        
        var tunnelIndex: Int? = nil
        
        accessQueue.sync {
            tunnelIndex = tunnels.index(of: tunnel)
        }
        
        guard let index = tunnelIndex else {
            // things went strange
            return
        }
        
        accessQueue.async(flags: .barrier) {
            self.tunnels.remove(at: index)
        }
    }
}
