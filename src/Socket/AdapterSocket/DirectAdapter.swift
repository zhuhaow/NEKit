import Foundation

/// This adapter connects to remote directly.
public class DirectAdapter: AdapterSocket {
    /// If this is set to `false`, then the IP address will be resolved by system.
    var resolveHost = false

    /**
     Connect to remote according to the `ConnectSession`.

     - parameter session: The connect session.
     */
    override public func openSocketWith(session: ConnectSession) {
        super.openSocketWith(session: session)

        guard !isCancelled else {
            return
        }

        do {
            try socket.connectTo(host: session.host, port: Int(session.port), enableTLS: false, tlsSettings: nil)
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
