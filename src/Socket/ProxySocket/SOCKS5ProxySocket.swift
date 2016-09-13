import Foundation

public class SOCKS5ProxySocket: ProxySocket {
    /// The remote host to connect to.
    public var destinationHost: String!

    /// The remote port to connect to.
    public var destinationPort: Int!

    /**
     Begin reading and processing data from the socket.
     */
    override func openSocket() {
        super.openSocket()
        socket.readDataToLength(2, withTag: SocketTag.SOCKS5.Open)
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    /**
     The socket did read some data.

     - parameter data:    The data read from the socket.
     - parameter withTag: The tag given when calling the `readData` method.
     - parameter from:    The socket where the data is read from.
     */
    override public func didReadData(data: NSData, withTag tag: Int, from: RawTCPSocketProtocol) {
        super.didReadData(data, withTag: tag, from: from)

        switch tag {
        case SocketTag.SOCKS5.Open:
            let pointer = UnsafePointer<UInt8>(data.bytes)

            guard pointer.memory == 5 else {
                // TODO: trigger error event
                return
            }

            guard pointer.successor().memory > 0 else {
                return
            }

            socket.readDataToLength(Int(pointer.successor().memory), withTag: SocketTag.SOCKS5.ConnectMethod)
        case SocketTag.SOCKS5.ConnectMethod:
            let response = NSData(bytes: [0x05, 0x00] as [UInt8], length: 2 * sizeof(UInt8))
            // we would not be able to read anything before the data is written out, so no need to handle the dataWrote event.
            writeData(response, withTag: SocketTag.SOCKS5.MethodResponse)
            socket.readDataToLength(4, withTag: SocketTag.SOCKS5.ConnectInit)
        case SocketTag.SOCKS5.ConnectInit:
            var requestInfo = [UInt8](count: 5, repeatedValue: 0)
            data.getBytes(&requestInfo, length: 5 * sizeof(UInt8))
            let addressType = requestInfo[3]
            switch addressType {
            case 1:
                socket.readDataToLength(4, withTag: SocketTag.SOCKS5.ConnectIPv4)
            case 3:
                socket.readDataToLength(1, withTag: SocketTag.SOCKS5.ConnectDomainLength)
            case 4:
                socket.readDataToLength(16, withTag: SocketTag.SOCKS5.ConnectIPv4)
            default:
                break
            }
        case SocketTag.SOCKS5.ConnectIPv4:
            var address = [Int8](count: Int(INET_ADDRSTRLEN), repeatedValue: 0)
            inet_ntop(AF_INET, data.bytes, &address, socklen_t(INET_ADDRSTRLEN))
            destinationHost = NSString(CString: &address, encoding: NSUTF8StringEncoding)! as String
            socket.readDataToLength(2, withTag: SocketTag.SOCKS5.ConnectPort)
        case SocketTag.SOCKS5.ConnectIPv6:
            var address = [Int8](count: Int(INET6_ADDRSTRLEN), repeatedValue: 0)
            inet_ntop(AF_INET, data.bytes, &address, socklen_t(INET6_ADDRSTRLEN))
            destinationHost = NSString(CString: &address, encoding: NSUTF8StringEncoding)! as String
            socket.readDataToLength(2, withTag: SocketTag.SOCKS5.ConnectPort)
        case SocketTag.SOCKS5.ConnectDomainLength:
            let length: UInt8 = UnsafePointer<UInt8>(data.bytes).memory
            socket.readDataToLength(Int(length), withTag: SocketTag.SOCKS5.ConnectDomain)
        case SocketTag.SOCKS5.ConnectDomain:
            destinationHost = NSString(bytes: data.bytes, length: data.length, encoding: NSUTF8StringEncoding)! as String
            socket.readDataToLength(2, withTag: SocketTag.SOCKS5.ConnectPort)
        case SocketTag.SOCKS5.ConnectPort:
            var rawPort: UInt16 = 0
            data.getBytes(&rawPort, length: sizeof(UInt16))
            destinationPort = Int(NSSwapBigShortToHost(rawPort))
            request = ConnectRequest(host: destinationHost!, port: destinationPort!)
            observer?.signal(.ReceivedRequest(request!, on: self))
            delegate?.didReceiveRequest(request!, from: self)
        case _ where tag >= 0:
            delegate?.didReadData(data, withTag: tag, from: self)
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
    override public func didWriteData(data: NSData?, withTag tag: Int, from: RawTCPSocketProtocol) {
        super.didWriteData(data, withTag: tag, from: from)

        if tag >= 0 {
            delegate?.didWriteData(data, withTag: tag, from: self)
        }
        if tag == SocketTag.SOCKS5.ConnectResponse {
            observer?.signal(.ReadyForForward(self))
            delegate?.readyToForward(self)
        }
    }

    /**
     Response to the `ConnectResponse` from `AdapterSocket` on the other side of the `Tunnel`.

     - parameter response: The `ConnectResponse`.
     */
    override func respondToResponse(response: ConnectResponse) {
        super.respondToResponse(response)

        var responseBytes = [UInt8](count: 10, repeatedValue: 0)
        responseBytes[0...3] = [0x05, 0x00, 0x00, 0x01]
        let responseData = NSData(bytes: &responseBytes, length: 10)
        writeData(responseData, withTag: SocketTag.SOCKS5.ConnectResponse)
    }
}
