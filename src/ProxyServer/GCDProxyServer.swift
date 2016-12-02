import Foundation
import CocoaAsyncSocket

/// Proxy server which listens on some port by GCDAsyncSocket.
///
/// This shoule be the base class for any concrete implementaion of proxy server (e.g., HTTP or SOCKS5) which needs to listen on some port.
open class GCDProxyServer: ProxyServer, GCDAsyncSocketDelegate {
    fileprivate let listenQueue: DispatchQueue = DispatchQueue(label: "NEKit.GCDProxyServer.listenQueue", attributes: [])
    fileprivate var listenSocket: GCDAsyncSocket!

    fileprivate var pendingSocket: [GCDTCPSocket] = []

    fileprivate var canHandleNewSocket: Bool {
        return Opt.ProxyActiveSocketLimit <= 0 || tunnels.value.count < Opt.ProxyActiveSocketLimit
    }

    /**
     Start the proxy server which creates a GCDAsyncSocket listening on specific port.

     - throws: The error occured when starting the proxy server.
     */
    override open func start() throws {
        listenSocket = GCDAsyncSocket(delegate: self, delegateQueue: listenQueue)
        try listenSocket.accept(onInterface: address?.presentation, port: port.value)
        try super.start()
    }

    /**
     Stop the proxy server.
     */
    override open func stop() {
        listenQueue.sync {
            for socket in self.pendingSocket {
                socket.disconnect()
            }
        }
        pendingSocket.removeAll()

        listenSocket?.setDelegate(nil, delegateQueue: nil)
        listenSocket?.disconnect()
        listenSocket = nil
        super.stop()
    }

    /**
     Delegate method to handle the newly accepted GCDTCPSocket.

     Only this method should be overrided in any concrete implementaion of proxy server which listens on some port with GCDAsyncSocket.

     - parameter socket: The accepted socket.
     */
    func handleNewGCDSocket(_ socket: GCDTCPSocket) {

    }

    /**
     GCDAsyncSocket delegate callback.

     - parameter sock:      The listening GCDAsyncSocket.
     - parameter newSocket: The accepted new GCDAsyncSocket.

     - warning: Do not call this method. This should be marked private but have to be marked public since the `GCDAsyncSocketDelegate` is public.
     */
    open func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        let gcdTCPSocket = GCDTCPSocket(socket: newSocket)

        if canHandleNewSocket {
            handleNewGCDSocket(gcdTCPSocket)
        } else {
            pendingSocket.append(gcdTCPSocket)
            NSLog("Current Pending socket \(pendingSocket.count)")
        }
    }

    override func tunnelDidClose(_ tunnel: Tunnel) {
        super.tunnelDidClose(tunnel)
        processPendingSocket()
    }

    func processPendingSocket() {
        listenQueue.async {
            while self.pendingSocket.count > 0 && self.canHandleNewSocket {
                let socket = self.pendingSocket.removeFirst()
                if socket.isConnected {
                    self.handleNewGCDSocket(socket)
                }
                NSLog("Current Pending socket \(self.pendingSocket.count)")
            }
        }
    }
}
