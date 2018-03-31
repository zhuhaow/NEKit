import Foundation

/// The SOCKS5 proxy server.
public final class GCDSOCKS5ProxyServer: GCDProxyServer {
    /**
     Create an instance of SOCKS5 proxy server.

     - parameter address: The address of proxy server.
     - parameter port:    The port of proxy server.
     */
    override public init(address: IPAddress?, port: Port) {
        super.init(address: address, port: port)
    }

    /**
     Handle the new accepted socket as a SOCKS5 proxy connection.

     - parameter socket: The accepted socket.
     */
    override open func handleNewGCDSocket(_ socket: GCDTCPSocket) {
        let proxySocket = SOCKS5ProxySocket(socket: socket)
        didAcceptNewSocket(proxySocket)
    }
}
