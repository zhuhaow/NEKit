import Foundation

public class HTTPProxySocket: ProxySocket {
    enum HTTPProxyStatus: CustomStringConvertible {
        case invalid,
        readingFirstHeader,
        waitingAdapter,
        sendingConnectResponse,
        waitingToForward,
        readingHeader,
        readingContent,
        stopped

        var description: String {
            switch self {
            case .invalid:
                return "invalid"
            case .readingFirstHeader:
                return "reading first header"
            case .waitingAdapter:
                return "waiting adpater to be ready"
            case .sendingConnectResponse:
                return "sending response header for CONNECT"
            case .waitingToForward:
                return "waiting to begin forwarding data"
            case .readingHeader:
                return "reading header (forwarding)"
            case .readingContent:
                return "reading content (forwarding)"
            case .stopped:
                return "stopped"
            }
        }
    }
    /// The remote host to connect to.
    public var destinationHost: String!

    /// The remote port to connect to.
    public var destinationPort: Int!

    private var currentHeader: HTTPHeader!

    private let scanner: HTTPStreamScanner = HTTPStreamScanner()

    private var internalStatus: HTTPProxyStatus = .invalid

    public var isConnectCommand = false

    public override var statusDescription: String {
        return "\(status) (\(internalStatus))"
    }

    /**
     Begin reading and processing data from the socket.
     */
    override public func openSocket() {
        super.openSocket()

        guard !isCancelled else {
            return
        }

        internalStatus = .readingFirstHeader
        socket.readDataTo(data: Utils.HTTPData.DoubleCRLF)
    }

    override public func readData() {
        guard !isCancelled else {
            return
        }

        // Return the first header we read when the socket was opened if the proxy command is not CONNECT.
        if internalStatus == .waitingToForward && !isConnectCommand {
            delegate?.didRead(data: currentHeader.toData(), from: self)
            internalStatus = .readingContent
            return
        }

        switch scanner.nextAction {
        case .readContent(let length):
            internalStatus = .readingContent
            if length > 0 {
                socket.readDataTo(length: length)
            } else {
                socket.readData()
            }
        case .readHeader:
            internalStatus = .readingHeader
            socket.readDataTo(data: Utils.HTTPData.DoubleCRLF)
        case .stop:
            internalStatus = .stopped
            disconnect()
        }

    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    /**
     The socket did read some data.
     
     - parameter data:    The data read from the socket.
     - parameter from:    The socket where the data is read from.
     */
    override public func didRead(data: Data, from: RawTCPSocketProtocol) {
        super.didRead(data: data, from: from)

        switch internalStatus {
        case .readingFirstHeader:
            guard let header = scanner.input(data).0 else {
                // TODO: indicate observer
                disconnect()
                return
            }

            currentHeader = header
            currentHeader.removeProxyHeader()
            currentHeader.rewriteToRelativePath()

            destinationHost = currentHeader.host
            destinationPort = currentHeader.port
            isConnectCommand = currentHeader.isConnect

            internalStatus = .waitingAdapter

            request = ConnectRequest(host: destinationHost!, port: destinationPort!)
            observer?.signal(.receivedRequest(request!, on: self))
            delegate?.didReceive(request: request!, from: self)
        case .readingHeader:
            guard let header = scanner.input(data).0 else {
                // TODO: indicate observer
                disconnect()
                return
            }

            currentHeader = header
            currentHeader.removeProxyHeader()
            currentHeader.rewriteToRelativePath()

            delegate?.didRead(data: currentHeader.toData(), from: self)
        case .readingContent:
            guard let content = scanner.input(data).1 else {
                disconnect()
                return
            }

            delegate?.didRead(data: content, from: self)
        default:
            return
        }
    }

    /**
     The socket did send some data.
     
     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter by:    The socket where the data is sent out.
     */
    override public func didWrite(data: Data?, by: RawTCPSocketProtocol) {
        super.didWrite(data: data, by: by)

        switch internalStatus {
        case .sendingConnectResponse:
            internalStatus = .waitingToForward
            observer?.signal(.readyForForward(self))
            delegate?.didBecomeReadyToForwardWith(socket: self)
        default:
            delegate?.didWrite(data: data, by: self)
        }
    }

    /**
     Response to the `AdapterSocket` on the other side of the `Tunnel` which has succefully connected to the remote server.
     
     - parameter adapter: The `AdapterSocket`.
     */
    public override func respondTo(adapter: AdapterSocket) {
        super.respondTo(adapter: adapter)

        guard !isCancelled else {
            return
        }

        // TODO: notify observer
        guard internalStatus == .waitingAdapter else {
            return
        }

        if isConnectCommand {
            internalStatus = .sendingConnectResponse
            write(data: Utils.HTTPData.ConnectSuccessResponse)
        } else {
            internalStatus = .waitingToForward
            observer?.signal(.readyForForward(self))
            delegate?.didBecomeReadyToForwardWith(socket: self)
        }
    }
}
