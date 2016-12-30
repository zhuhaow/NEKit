import Foundation

/// This class just forwards data directly. 
/// - note: It is designed to work with tun2socks only.
public class DirectProxySocket: ProxySocket {
    enum DirectProxyReadStatus: CustomStringConvertible {
        case invalid,
        forwarding,
        stopped

        var description: String {
            switch self {
            case .invalid:
                return "invalid"
            case .forwarding:
                return "forwarding"
            case .stopped:
                return "stopped"
            }
        }
    }

    enum DirectProxyWriteStatus {
        case invalid,
        forwarding,
        stopped

        var description: String {
            switch self {
            case .invalid:
                return "invalid"
            case .forwarding:
                return "forwarding"
            case .stopped:
                return "stopped"
            }
        }
    }

    private var readStatus: DirectProxyReadStatus = .invalid
    private var writeStatus: DirectProxyWriteStatus = .invalid

    public var readStatusDescription: String {
        return readStatus.description
    }

    public var writeStatusDescription: String {
        return writeStatus.description
    }

    /**
     Begin reading and processing data from the socket.

     - note: Since there is nothing to read and process before forwarding data, this just calls `delegate?.didReceiveRequest`.
     */
    override public func openSocket() {
        super.openSocket()

        guard !isCancelled else {
            return
        }

        if let address = socket.destinationIPAddress, let port = socket.destinationPort {
            session = ConnectSession(host: address.presentation, port: Int(port.value))

            observer?.signal(.receivedRequest(session!, on: self))
            delegate?.didReceive(session: session!, from: self)
        } else {
            forceDisconnect()
        }
    }

    /**
     Response to the `AdapterSocket` on the other side of the `Tunnel` which has succefully connected to the remote server.
     
     - parameter adapter: The `AdapterSocket`.
     */
    override public func respondTo(adapter: AdapterSocket) {
        super.respondTo(adapter: adapter)

        guard !isCancelled else {
            return
        }

        readStatus = .forwarding
        writeStatus = .forwarding

        observer?.signal(.readyForForward(self))
        delegate?.didBecomeReadyToForwardWith(socket: self)
    }

    /**
     The socket did read some data.

     - parameter data:    The data read from the socket.
     - parameter from:    The socket where the data is read from.
     */
    override open func didRead(data: Data, from: RawTCPSocketProtocol) {
        super.didRead(data: data, from: from)
        delegate?.didRead(data: data, from: self)
    }

    /**
     The socket did send some data.

     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter by:    The socket where the data is sent out.
     */
    override open func didWrite(data: Data?, by: RawTCPSocketProtocol) {
        super.didWrite(data: data, by: by)
        delegate?.didWrite(data: data, by: self)
    }
}
