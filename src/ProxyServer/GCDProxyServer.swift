import Foundation
import CocoaAsyncSocket

/// Proxy server which listens on some port by GCDAsyncSocket.
///
/// This shoule be the base class for any concrete implementation of proxy server (e.g., HTTP or SOCKS5) which needs to listen on some port.
open class GCDProxyServer: ProxyServer, GCDAsyncSocketDelegate {
    fileprivate var listenSocket: GCDAsyncSocket!

    /**
     Start the proxy server which creates a GCDAsyncSocket listening on specific port.
     
     - throws: The error occured when starting the proxy server.
     */
    override open func start() throws {
        try QueueFactory.executeOnQueueSynchronizedly {
            listenSocket = GCDAsyncSocket(delegate: self, delegateQueue: QueueFactory.getQueue(), socketQueue: QueueFactory.getQueue())
            try listenSocket.accept(onInterface: address?.presentation, port: port.value)
            try super.start()
        }
    }

    /**
     Stop the proxy server.
     */
    override open func stop() {
        QueueFactory.executeOnQueueSynchronizedly {
            listenSocket?.setDelegate(nil, delegateQueue: nil)
            listenSocket?.disconnect()
            listenSocket = nil
            super.stop()
        }
    }

    /**
     Delegate method to handle the newly accepted GCDTCPSocket.
     
     Only this method should be overrided in any concrete implementation of proxy server which listens on some port with GCDAsyncSocket.
     
     - parameter socket: The accepted socket.
     */
    open func handleNewGCDSocket(_ socket: GCDTCPSocket) {

    }

    /**
     GCDAsyncSocket delegate callback.
     
     - parameter sock:      The listening GCDAsyncSocket.
     - parameter newSocket: The accepted new GCDAsyncSocket.
     
     - warning: Do not call this method. This should be marked private but have to be marked public since the `GCDAsyncSocketDelegate` is public.
     */
    open func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        let gcdTCPSocket = GCDTCPSocket(socket: newSocket)
        handleNewGCDSocket(gcdTCPSocket)
    }

    public func newSocketQueueForConnection(fromAddress address: Data, on sock: GCDAsyncSocket) -> DispatchQueue? {
        return QueueFactory.getQueue()
    }
}
