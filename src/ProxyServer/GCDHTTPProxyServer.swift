import Foundation

/// The HTTP proxy server.
public final class GCDHTTPProxyServer: GCDProxyServer {
    /**
     Create an instance of HTTP proxy server.

     - parameter address: The address of proxy server.
     - parameter port:    The port of proxy server.
     */
    override public init(address: IPAddress?, port: Port) {
        super.init(address: address, port: port)
    }

    /**
     Handle the new accepted socket as a HTTP proxy connection.

     - parameter socket: The accepted socket.
     */
    override public func handleNewGCDSocket(_ socket: GCDTCPSocket) {
        let proxySocket = HTTPProxySocket(socket: socket)
        didAcceptNewSocket(proxySocket)
    }
}
