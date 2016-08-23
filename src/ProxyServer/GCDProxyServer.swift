import Foundation
import CocoaAsyncSocket

/// Proxy server which listens on some port by GCDAsyncSocket.
///
/// This shoule be the base class for any concrete implemention of proxy server (e.g., HTTP or SOCKS5) which needs to listen on some port.
public class GCDProxyServer: ProxyServer, GCDAsyncSocketDelegate {
    private let listenQueue: dispatch_queue_t = dispatch_queue_create("NEKit.GCDProxyServer.listenQueue", DISPATCH_QUEUE_SERIAL)
    private var listenSocket: GCDAsyncSocket!

    /**
     Start the proxy server which creates a GCDAsyncSocket listening on specific port.

     - throws: The error occured when starting the proxy server.
     */
    override public func start() throws {
        listenSocket = GCDAsyncSocket(delegate: self, delegateQueue: listenQueue)
        try listenSocket.acceptOnInterface(address?.presentation, port: port.value)
        try super.start()
    }

    /**
     Stop the proxy server.
     */
    override public func stop() {
        listenSocket?.setDelegate(nil, delegateQueue: nil)
        listenSocket?.disconnect()
        listenSocket = nil
        super.stop()
    }

    /**
     Delegate method to handle the newly accepted GCDTCPSocket.

     Only this method should be overrided in any concrete implemention of proxy server which listens on some port with GCDAsyncSocket.

     - parameter socket: The accepted socket.
     */
    func handleNewGCDSocket(socket: GCDTCPSocket) {

    }

    /**
     GCDAsyncSocket delegate callback.

     - parameter sock:      The listening GCDAsyncSocket.
     - parameter newSocket: The accepted new GCDAsyncSocket.

     - warning: Do not call this method. This should be marked  private but have to be marked public since the `GCDAsyncSocketDelegate` is public.
     */
    public func socket(sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        let gcdTCPSocket = GCDTCPSocket(socket: newSocket)
        handleNewGCDSocket(gcdTCPSocket)
    }
}
