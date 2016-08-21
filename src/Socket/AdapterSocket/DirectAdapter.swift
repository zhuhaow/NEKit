import Foundation

/// This adapter connects to remote directly.
public class DirectAdapter: AdapterSocket {
    /// If this is set to `false`, then the IP address will be resolved by system.
    var resolveHost = false

    override init() {
        super.init()
        type = "Direct"
    }

    /**
     Connect to remote according to the `ConnectRequest`.

     - parameter request: The connect request.
     */
    override func openSocketWithRequest(request: ConnectRequest) {
        super.openSocketWithRequest(request)

        do {
            try socket.connectTo(request.host, port: Int(request.port), enableTLS: false, tlsSettings: nil)
        } catch let error {
            observer?.signal(.ErrorOccured(error, on: self))
            disconnect()
        }
    }

    /**
     The socket did connect to remote.

     - parameter socket: The connected socket.
     */
    override public func didConnect(socket: RawTCPSocketProtocol) {
        super.didConnect(socket)
        observer?.signal(.ReadyForForward(self))
        delegate?.readyToForward(self)
    }

    override public func didReadData(data: NSData, withTag tag: Int, from rawSocket: RawTCPSocketProtocol) {
        super.didReadData(data, withTag: tag, from: rawSocket)
        delegate?.didReadData(data, withTag: tag, from: self)
    }

    override public func didWriteData(data: NSData?, withTag tag: Int, from rawSocket: RawTCPSocketProtocol) {
        super.didWriteData(data, withTag: tag, from: rawSocket)
        delegate?.didWriteData(data, withTag: tag, from: self)
    }
}
