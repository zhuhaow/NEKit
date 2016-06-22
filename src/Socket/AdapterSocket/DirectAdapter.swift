import Foundation
import CocoaLumberjackSwift

/// This adapter connects to remote directly.
class DirectAdapter: AdapterSocket {
    /// If this is set to `false`, then the IP address will be resolved by system.
    var resolveHost = false

    /**
     Connect to remote according to the `ConnectRequest`.

     - parameter request: The connect request.
     */
    override func openSocketWithRequest(request: ConnectRequest) {
        super.openSocketWithRequest(request)
        let host: String
        if resolveHost {
            host = request.ipAddress
            if host == "" {
                DDLogError("DNS look up failed for direct connect to \(request.host), disconnect now.")
                delegate?.didDisconnect(self)
            }
        } else {
            host = request.host
        }
        do {
            try socket.connectTo(host, port: Int(request.port), enableTLS: false, tlsSettings: nil)
        } catch {}
    }

    /**
     The socket did connect to remote.

     - parameter socket: The connected socket.
     */
    override func didConnect(socket: RawTCPSocketProtocol) {
        super.didConnect(socket)
        delegate?.readyToForward(self)
    }
}
