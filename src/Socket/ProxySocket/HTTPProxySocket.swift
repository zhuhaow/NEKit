import Foundation
import CocoaLumberjackSwift

class HTTPProxySocket: ProxySocket {
    /// The remote host to connect to.
    var destinationHost: String!

    /// The remote port to connect to.
    var destinationPort: Int!

    private var firstHeader: Bool = true

    private var currentHeader: HTTPHeader!

    private var currentReadTag: Int!

    private let scanner: HTTPStreamScanner = HTTPStreamScanner()

    private var isConnect = false

    /**
     Begin reading and processing data from the socket.
     */
    override func openSocket() {
        super.openSocket()
        socket.readDataToData(Utils.HTTPData.DoubleCRLF, withTag: SocketTag.HTTP.Header)
    }

    override func readDataWithTag(tag: Int = SocketTag.Forward) {
        currentReadTag = tag

        if firstHeader {
            firstHeader = false
            if !isConnect {
                delegate?.didReadData(currentHeader.toData(), withTag: tag, from: self)
                return
            }
        }

        switch scanner.nextAction {
        case .ReadContent(let length):
            if length > 0 {
                socket.readDataToLength(length, withTag: SocketTag.HTTP.Content)
            } else {
                socket.readDataWithTag(SocketTag.HTTP.Content)
            }
        case .ReadHeader:
            socket.readDataToData(Utils.HTTPData.DoubleCRLF, withTag: SocketTag.HTTP.Header)
        case .Stop:
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
    override func didReadData(data: NSData, withTag tag: Int, from: RawTCPSocketProtocol) {
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
            DDLogError("HTTPProxySocket recieved some data with unknown data tag: \(tag)")
            break
        }
    }

    /**
     The socket did send some data.

     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter withTag: The tag given when calling the `writeData` method.
     - parameter from:    The socket where the data is sent out.
     */
    override func didWriteData(data: NSData?, withTag tag: Int, from: RawTCPSocketProtocol) {
        super.didWriteData(data, withTag: tag, from: from)

        if tag >= 0 {
            delegate?.didWriteData(data, withTag: tag, from: self)
        }
        if tag == SocketTag.HTTP.ConnectResponse {
            delegate?.readyToForward(self)
        }
    }

    override func respondToResponse(response: ConnectResponse) {
        if isConnect {
            writeData(Utils.HTTPData.ConnectSuccessResponse, withTag: SocketTag.HTTP.ConnectResponse)
        } else {
            delegate?.readyToForward(self)
        }
    }
}
