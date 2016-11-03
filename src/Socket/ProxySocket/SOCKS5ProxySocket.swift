import Foundation

open class SOCKS5ProxySocket: ProxySocket {
    /// The remote host to connect to.
    open var destinationHost: String!

    /// The remote port to connect to.
    open var destinationPort: Int!

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
    override open func didReadData(_ data: Data, withTag tag: Int, from: RawTCPSocketProtocol) {
        super.didReadData(data, withTag: tag, from: from)

        switch tag {
        case SocketTag.SOCKS5.Open:
            let pointer = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)

            guard pointer.pointee == 5 else {
                // TODO: trigger error event
                return
            }

            guard pointer.successor().pointee > 0 else {
                return
            }

            socket.readDataToLength(Int(pointer.successor().pointee), withTag: SocketTag.SOCKS5.ConnectMethod)
        case SocketTag.SOCKS5.ConnectMethod:
            let response = Data(bytes: UnsafePointer<UInt8>([0x05, 0x00] as [UInt8]), count: 2 * MemoryLayout<UInt8>.size)
            // we would not be able to read anything before the data is written out, so no need to handle the dataWrote event.
            writeData(response, withTag: SocketTag.SOCKS5.MethodResponse)
            socket.readDataToLength(4, withTag: SocketTag.SOCKS5.ConnectInit)
        case SocketTag.SOCKS5.ConnectInit:
            var requestInfo = [UInt8](repeating: 0, count: 5)
            (data as NSData).getBytes(&requestInfo, length: 5 * MemoryLayout<UInt8>.size)
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
            var address = [Int8](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, (data as NSData).bytes, &address, socklen_t(INET_ADDRSTRLEN))
            destinationHost = NSString(cString: &address, encoding: String.Encoding.utf8.rawValue)! as String
            socket.readDataToLength(2, withTag: SocketTag.SOCKS5.ConnectPort)
        case SocketTag.SOCKS5.ConnectIPv6:
            var address = [Int8](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            inet_ntop(AF_INET6, (data as NSData).bytes, &address, socklen_t(INET6_ADDRSTRLEN))
            destinationHost = NSString(cString: &address, encoding: String.Encoding.utf8.rawValue)! as String
            socket.readDataToLength(2, withTag: SocketTag.SOCKS5.ConnectPort)
        case SocketTag.SOCKS5.ConnectDomainLength:
            let length: UInt8 = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee
            socket.readDataToLength(Int(length), withTag: SocketTag.SOCKS5.ConnectDomain)
        case SocketTag.SOCKS5.ConnectDomain:
            destinationHost = NSString(bytes: (data as NSData).bytes, length: data.count, encoding: String.Encoding.utf8.rawValue)! as String
            socket.readDataToLength(2, withTag: SocketTag.SOCKS5.ConnectPort)
        case SocketTag.SOCKS5.ConnectPort:
            var rawPort: UInt16 = 0
            (data as NSData).getBytes(&rawPort, length: MemoryLayout<UInt16>.size)
            destinationPort = Int(NSSwapBigShortToHost(rawPort))
            request = ConnectRequest(host: destinationHost!, port: destinationPort!)
            observer?.signal(.receivedRequest(request!, on: self))
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
    override open func didWriteData(_ data: Data?, withTag tag: Int, from: RawTCPSocketProtocol) {
        super.didWriteData(data, withTag: tag, from: from)

        if tag >= 0 {
            delegate?.didWriteData(data, withTag: tag, from: self)
        }
        if tag == SocketTag.SOCKS5.ConnectResponse {
            observer?.signal(.readyForForward(self))
            delegate?.readyToForward(self)
        }
    }

    /**
     Response to the `ConnectResponse` from `AdapterSocket` on the other side of the `Tunnel`.

     - parameter response: The `ConnectResponse`.
     */
    override func respondToResponse(_ response: ConnectResponse) {
        super.respondToResponse(response)

        var responseBytes = [UInt8](repeating: 0, count: 10)
        responseBytes[0...3] = [0x05, 0x00, 0x00, 0x01]
        let responseData = Data(bytes: responseBytes)
        writeData(responseData, withTag: SocketTag.SOCKS5.ConnectResponse)
    }
}
