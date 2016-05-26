import Foundation
import CocoaAsyncSocket
import CocoaLumberjackSwift

public class SOCKS5ProxyServer: ProxyServer, GCDAsyncSocketDelegate {
    let listenQueue: dispatch_queue_t = dispatch_queue_create("me.zhuhaow.Specht.listenQueue", DISPATCH_QUEUE_SERIAL)
    var listenSocket: GCDAsyncSocket!


    override public func start() -> Bool {
        listenSocket = GCDAsyncSocket(delegate: self, delegateQueue: listenQueue)
        do {
            try listenSocket.acceptOnInterface(address, port: UInt16(port))
            DDLogInfo("Successfully start SOCK5 proxy server on port \(port).")
            return super.start()
        } catch let error as NSError {
            DDLogError("Failed to start SOCKS5 proxy server. \(error.localizedDescription)")
            return false
        }
    }

    override public func stop() {
        listenSocket.setDelegate(nil, delegateQueue: nil)
        listenSocket.disconnect()
        listenSocket = nil
        super.stop()
    }

    public func socket(sock: GCDAsyncSocket!, didAcceptNewSocket newSocket: GCDAsyncSocket!) {
        DDLogVerbose("Proxy server accepted new socket.")
        let gcdTCPSocket = GCDTCPSocket(socket: newSocket)
        let proxySocket = SOCKS5ProxySocket(socket: gcdTCPSocket)
        didAcceptNewSocket(proxySocket)
    }

    override func tunnelDidClose(tunnel: Tunnel) {
        dispatch_async(listenQueue) {
            super.tunnelDidClose(tunnel)
        }
    }

    public override func inQueue(block: () -> ()) {
        dispatch_async(listenQueue, block)
    }
}
