import Foundation
import CocoaLumberjackSwift

class DirectAdapter : AdapterSocket {
    var resolveHost = false
    
    override func openSocketWithRequest(request: ConnectRequest) {
        super.openSocketWithRequest(request)
        let host: String
        if resolveHost {
            host = request.IP
            if host == "" {
                DDLogError("DNS look up failed for direct connect to \(request.host), disconnect now.")
                delegate?.didDisconnect(self)
            }
        } else {
            host = request.host
        }
        socket.connectTo(host, port: Int(request.port), enableTLS: false, tlsSettings: nil)
    }
    
    override func didConnect(socket: RawSocketProtocol) {
        super.didConnect(socket)
        delegate?.readyForForward(self)
    }
}