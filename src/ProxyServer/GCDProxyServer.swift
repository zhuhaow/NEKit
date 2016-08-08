import Foundation
import CocoaAsyncSocket
import CocoaLumberjackSwift

/// Proxy server which listens on some port by GCDAsyncSocket.
///
/// This shoule be the base class for any concrete implemention of proxy server (e.g., HTTP or SOCKS5) which needs to listen on some port.
public class GCDProxyServer: ProxyServer, GCDAsyncSocketDelegate {
    private let listenQueue: dispatch_queue_t = dispatch_queue_create("NEKit.GCDProxyServer.listenQueue", DISPATCH_QUEUE_SERIAL)
    private var listenSocket: GCDAsyncSocket!

    /// The type of the proxy server.
    ///
    /// This can be set to anything describing the proxy server.
    public var type = ""

    /// The description of proxy server.
    public override var description: String {
        return "\(type) proxy server: address: \(address); port: \(port)"
    }

    /**
     Start the proxy server which creates a GCDAsyncSocket listening on specific port.

     - throws: The error occured when starting the proxy server.
     */
    override public func start() throws {
        listenSocket = GCDAsyncSocket(delegate: self, delegateQueue: listenQueue)
        try listenSocket.acceptOnInterface(address.presentation, port: port.value)
        DDLogInfo("Successfully started \(self) on \(port).")
        try super.start()
    }

    /**
     Stop the proxy server.
     */
    override public func stop() {
        DDLogInfo("Stopping \(self).")
        listenSocket?.setDelegate(nil, delegateQueue: nil)
        listenSocket?.disconnect()
        listenSocket = nil
        super.stop()
        DDLogInfo("Successfully stopped \(self).")
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
        DDLogVerbose("\(self) accepted new socket.")
        let gcdTCPSocket = GCDTCPSocket(socket: newSocket)
        DDLogDebug("\(self) accepted a new socket from \(gcdTCPSocket.sourceIPAddress):\(gcdTCPSocket.sourcePort)")
        handleNewGCDSocket(gcdTCPSocket)
    }

}
