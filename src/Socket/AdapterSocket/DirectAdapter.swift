import Foundation

/// This adapter connects to remote directly.
public class DirectAdapter: AdapterSocket {
    /// If this is set to `false`, then the IP address will be resolved by system.
    var resolveHost = false

    /**
     Connect to remote according to the `ConnectRequest`.

     - parameter request: The connect request.
     */
    override public func openSocketWith(request: ConnectRequest) {
        super.openSocketWith(request: request)

        guard !isCancelled else {
            return
        }

        do {
            try socket.connectTo(host: request.host, port: Int(request.port), enableTLS: false, tlsSettings: nil)
        } catch let error {
            observer?.signal(.errorOccured(error, on: self))
            disconnect()
        }
    }

    /**
     The socket did connect to remote.

     - parameter socket: The connected socket.
     */
    override public func didConnectWith(socket: RawTCPSocketProtocol) {
        super.didConnectWith(socket: socket)
        observer?.signal(.readyForForward(self))
        delegate?.didBecomeReadyToForwardWith(socket: self)
    }

    override public func didRead(data: Data, from rawSocket: RawTCPSocketProtocol) {
        super.didRead(data: data, from: rawSocket)
        delegate?.didRead(data: data, from: self)
    }

    override public func didWrite(data: Data?, by rawSocket: RawTCPSocketProtocol) {
        super.didWrite(data: data, by: rawSocket)
        delegate?.didWrite(data: data, by: self)
    }
}
