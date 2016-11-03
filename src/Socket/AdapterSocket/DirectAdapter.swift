import Foundation

/// This adapter connects to remote directly.
open class DirectAdapter: AdapterSocket {
    /// If this is set to `false`, then the IP address will be resolved by system.
    var resolveHost = false

    public override init() {
        super.init()
    }

    /**
     Connect to remote according to the `ConnectRequest`.

     - parameter request: The connect request.
     */
    override func openSocketWithRequest(_ request: ConnectRequest) {
        super.openSocketWithRequest(request)

        do {
            try socket.connectTo(request.host, port: Int(request.port), enableTLS: false, tlsSettings: nil)
        } catch let error {
            observer?.signal(.errorOccured(error, on: self))
            disconnect()
        }
    }

    /**
     The socket did connect to remote.

     - parameter socket: The connected socket.
     */
    override open func didConnect(_ socket: RawTCPSocketProtocol) {
        super.didConnect(socket)
        observer?.signal(.readyForForward(self))
        delegate?.readyToForward(self)
    }

    override open func didReadData(_ data: Data, withTag tag: Int, from rawSocket: RawTCPSocketProtocol) {
        super.didReadData(data, withTag: tag, from: rawSocket)
        delegate?.didReadData(data, withTag: tag, from: self)
    }

    override open func didWriteData(_ data: Data?, withTag tag: Int, from rawSocket: RawTCPSocketProtocol) {
        super.didWriteData(data, withTag: tag, from: rawSocket)
        delegate?.didWriteData(data, withTag: tag, from: self)
    }
}
