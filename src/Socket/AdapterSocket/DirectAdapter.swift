import Foundation
import CocoaLumberjackSwift

class DirectAdapter: AdapterSocket {
    var resolveHost = false

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

    override func didConnect(socket: RawTCPSocketProtocol) {
        super.didConnect(socket)
        delegate?.readyForForward(self)
    }
}
