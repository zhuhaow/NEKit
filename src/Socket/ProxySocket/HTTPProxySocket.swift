import Foundation

open class HTTPProxySocket: ProxySocket {
    /// The remote host to connect to.
    open var destinationHost: String!

    /// The remote port to connect to.
    open var destinationPort: Int!

    fileprivate var firstHeader: Bool = true

    fileprivate var currentHeader: HTTPHeader!

    fileprivate var currentReadTag: Int!

    fileprivate let scanner: HTTPStreamScanner = HTTPStreamScanner()

    fileprivate var isConnect = false

    /**
     Begin reading and processing data from the socket.
     */
    override func openSocket() {
        super.openSocket()
        socket.readDataToData(Utils.HTTPData.DoubleCRLF, withTag: SocketTag.HTTP.Header)
    }

    override open func readDataWithTag(_ tag: Int = SocketTag.Forward) {
        currentReadTag = tag

        if firstHeader {
            firstHeader = false
            if !isConnect {
                delegate?.didReadData(currentHeader.toData(), withTag: tag, from: self)
                return
            }
        }

        switch scanner.nextAction {
        case .readContent(let length):
            if length > 0 {
                socket.readDataToLength(length, withTag: SocketTag.HTTP.Content)
            } else {
                socket.readDataWithTag(SocketTag.HTTP.Content)
            }
        case .readHeader:
            socket.readDataToData(Utils.HTTPData.DoubleCRLF, withTag: SocketTag.HTTP.Header)
        case .stop:
            disconnect()
        }

    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    /**
     The socket did read some data.

     - parameter data:    The data read from the socket.
     - parameter withTag: The tag given when calling the `readData` method.
     - parameter from:    The socket where the data is read from.
     */
    override open func didReadData(_ data: Data, withTag tag: Int, from: RawTCPSocketProtocol) {
        super.didReadData(data, withTag: tag, from: from)

        switch tag {
        case SocketTag.HTTP.Header:
            guard let header = scanner.input(data).0 else {
                disconnect()
                return
            }

            currentHeader = header
            currentHeader.removeProxyHeader()
            currentHeader.rewriteToRelativePath()

            if firstHeader {
                destinationHost = currentHeader.host
                destinationPort = currentHeader.port
                isConnect = currentHeader.isConnect

                request = ConnectRequest(host: destinationHost!, port: destinationPort!)
                observer?.signal(.receivedRequest(request!, on: self))
                delegate?.didReceiveRequest(request!, from: self)
            } else {
                delegate?.didReadData(header.toData(), withTag: currentReadTag, from: self)
            }
        case SocketTag.HTTP.Content:
            guard let content = scanner.input(data).1 else {
                disconnect()
                return
            }

            delegate?.didReadData(content, withTag: currentReadTag, from: self)
        default:
            break
        }
    }

    /**
     The socket did send some data.

     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter withTag: The tag given when calling the `writeData` method.
     - parameter from:    The socket where the data is sent out.
     */
    override open func didWriteData(_ data: Data?, withTag tag: Int, from: RawTCPSocketProtocol) {
        super.didWriteData(data, withTag: tag, from: from)

        if tag >= 0 {
            delegate?.didWriteData(data, withTag: tag, from: self)
        }
        if tag == SocketTag.HTTP.ConnectResponse {
            observer?.signal(.readyForForward(self))
            delegate?.readyToForward(self)
        }
    }

    override func respondToResponse(_ response: ConnectResponse) {
        super.respondToResponse(response)

        if isConnect {
            writeData(Utils.HTTPData.ConnectSuccessResponse, withTag: SocketTag.HTTP.ConnectResponse)
        } else {
            observer?.signal(.readyForForward(self))
            delegate?.readyToForward(self)
        }
    }
}
