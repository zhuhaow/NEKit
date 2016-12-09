import Foundation

public class HTTPProxySocket: ProxySocket {
    enum HTTPProxyReadStatus: CustomStringConvertible {
        case invalid,
        readingFirstHeader,
        pendingFirstHeader,
        readingHeader,
        readingContent,
        stopped

        var description: String {
            switch self {
            case .invalid:
                return "invalid"
            case .readingFirstHeader:
                return "reading first header"
            case .pendingFirstHeader:
                return "waiting to send first header"
            case .readingHeader:
                return "reading header (forwarding)"
            case .readingContent:
                return "reading content (forwarding)"
            case .stopped:
                return "stopped"
            }
        }
    }

    enum HTTPProxyWriteStatus: CustomStringConvertible {
        case invalid,
        sendingConnectResponse,
        forwarding,
        stopped

        var description: String {
            switch self {
            case .invalid:
                return "invalid"
            case .sendingConnectResponse:
                return "sending response header for CONNECT"
            case .forwarding:
                return "waiting to begin forwarding data"
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

    private var readingStatus: HTTPProxyReadStatus = .invalid
    private var writingStatus: HTTPProxyWriteStatus = .invalid

    public var isConnectCommand = false

    public override var readStatusDescription: String {
        return readingStatus.description
    }
    
    public override var writeStatusDescription: String {
        return writingStatus.description
    }

    /**
     Begin reading and processing data from the socket.
     */
    override public func openSocket() {
        super.openSocket()

        guard !isCancelled else {
            return
        }

        readingStatus = .readingFirstHeader
        socket.readDataTo(data: Utils.HTTPData.DoubleCRLF)
    }

    override public func readData() {
        guard !isCancelled else {
            return
        }

        // Return the first header we read when the socket was opened if the proxy command is not CONNECT.
        if readingStatus == .pendingFirstHeader {
            delegate?.didRead(data: currentHeader.toData(), from: self)
            readingStatus = .readingContent
            return
        }

        switch scanner.nextAction {
        case .readContent(let length):
            readingStatus = .readingContent
            if length > 0 {
                socket.readDataTo(length: length)
            } else {
                socket.readData()
            }
        case .readHeader:
            readingStatus = .readingHeader
            socket.readDataTo(data: Utils.HTTPData.DoubleCRLF)
        case .stop:
            readingStatus = .stopped
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

        switch readingStatus {
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

            if !isConnectCommand {
                readingStatus = .pendingFirstHeader
            } else {
                readingStatus = .readingContent
            }

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

        switch writingStatus {
        case .sendingConnectResponse:
            writingStatus = .forwarding
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

        if isConnectCommand {
            writingStatus = .sendingConnectResponse
            write(data: Utils.HTTPData.ConnectSuccessResponse)
        } else {
            writingStatus = .forwarding
            observer?.signal(.readyForForward(self))
            delegate?.didBecomeReadyToForwardWith(socket: self)
        }
    }
}
