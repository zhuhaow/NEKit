import Foundation

public class SOCKS5ProxySocket: ProxySocket {
    enum SOCKS5ProxyReadStatus: CustomStringConvertible {
        case invalid,
        readingVersionIdentifierAndNumberOfMethods,
        readingMethods,
        readingConnectHeader,
        readingIPv4Address,
        readingDomainLength,
        readingDomain,
        readingIPv6Address,
        readingPort,
        forwarding,
        stopped

        var description: String {
            switch self {
            case .invalid:
                return "invalid"
            case .readingVersionIdentifierAndNumberOfMethods:
                return "reading version and methods"
            case .readingMethods:
                return "reading methods"
            case .readingConnectHeader:
                return "reading connect header"
            case .readingIPv4Address:
                return "IPv4 address"
            case .readingDomainLength:
                return "domain length"
            case .readingDomain:
                return "domain"
            case .readingIPv6Address:
                return "IPv6 address"
            case .readingPort:
                return "reading port"
            case .forwarding:
                return "forwarding"
            case .stopped:
                return "stopped"
            }
        }
    }

    enum SOCKS5ProxyWriteStatus: CustomStringConvertible {
        case invalid,
        sendingResponse,
        forwarding,
        stopped

        var description: String {
            switch self {
            case .invalid:
                return "invalid"
            case .sendingResponse:
                return "sending response"
            case .forwarding:
                return "forwarding"
            case .stopped:
                return "stopped"
            }
        }
    }
    /// The remote host to connect to.
    public var destinationHost: String!

    /// The remote port to connect to.
    public var destinationPort: Int!

    private var readStatus: SOCKS5ProxyReadStatus = .invalid
    private var writeStatus: SOCKS5ProxyWriteStatus = .invalid

    public var readStatusDescription: String {
        return readStatus.description
    }

    public var writeStatusDescription: String {
        return writeStatus.description
    }

    /**
     Begin reading and processing data from the socket.
     */
    override public func openSocket() {
        super.openSocket()

        guard !isCancelled else {
            return
        }

        readStatus = .readingVersionIdentifierAndNumberOfMethods
        socket.readDataTo(length: 2)
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

        switch readStatus {
        case .forwarding:
            delegate?.didRead(data: data, from: self)
        case .readingVersionIdentifierAndNumberOfMethods:
            data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) in
                guard pointer.pointee == 5 else {
                    // TODO: notify observer
                    self.disconnect()
                    return
                }

                guard pointer.successor().pointee > 0 else {
                    // TODO: notify observer
                    self.disconnect()
                    return
                }

                self.readStatus = .readingMethods
                self.socket.readDataTo(length: Int(pointer.successor().pointee))
            }
        case .readingMethods:
            // TODO: check for 0x00 in read data

            let response = Data(bytes: [0x05, 0x00])
            // we would not be able to read anything before the data is written out, so no need to handle the dataWrote event.
            write(data: response)
            readStatus = .readingConnectHeader
            socket.readDataTo(length: 4)
        case .readingConnectHeader:
            data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) in
                guard pointer.pointee == 5 && pointer.successor().pointee == 1 else {
                    // TODO: notify observer
                    self.disconnect()
                    return
                }
                switch pointer.advanced(by: 3).pointee {
                case 1:
                    readStatus = .readingIPv4Address
                    socket.readDataTo(length: 4)
                case 3:
                    readStatus = .readingDomainLength
                    socket.readDataTo(length: 1)
                case 4:
                    readStatus = .readingIPv6Address
                    socket.readDataTo(length: 16)
                default:
                    break
                }
            }
        case .readingIPv4Address:
            var address = Data(count: Int(INET_ADDRSTRLEN))
            _ = data.withUnsafeRawPointer { data_ptr in
                address.withUnsafeMutableBytes { addr_ptr in
                    inet_ntop(AF_INET, data_ptr, addr_ptr, socklen_t(INET_ADDRSTRLEN))
                }
            }

            address.withUnsafeBytes {
                destinationHost = String(cString: $0, encoding: .utf8)
            }

            readStatus = .readingPort
            socket.readDataTo(length: 2)
        case .readingIPv6Address:
            var address = Data(count: Int(INET6_ADDRSTRLEN))
            _ = data.withUnsafeRawPointer { data_ptr in
                address.withUnsafeMutableBytes { addr_ptr in
                    inet_ntop(AF_INET6, data_ptr, addr_ptr, socklen_t(INET6_ADDRSTRLEN))
                }
            }

            address.withUnsafeBytes {
                destinationHost = String(cString: $0, encoding: .utf8)
            }

            readStatus = .readingPort
            socket.readDataTo(length: 2)
        case .readingDomainLength:
            data.withUnsafeRawPointer {
                readStatus = .readingDomain
                socket.readDataTo(length: Int($0.load(as: UInt8.self)))
            }
        case .readingDomain:
            destinationHost = String(data: data, encoding: .utf8)
            readStatus = .readingPort
            socket.readDataTo(length: 2)
        case .readingPort:
            data.withUnsafeRawPointer {
                destinationPort = Int($0.load(as: UInt16.self).bigEndian)
            }

            readStatus = .forwarding
            session = ConnectSession(host: destinationHost, port: destinationPort)
            observer?.signal(.receivedRequest(session!, on: self))
            delegate?.didReceive(session: session!, from: self)
        default:
            return
        }
    }

    /**
     The socket did send some data.
     
     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter from:    The socket where the data is sent out.
     */
    override public func didWrite(data: Data?, by: RawTCPSocketProtocol) {
        super.didWrite(data: data, by: by)

        switch writeStatus {
        case .forwarding:
            delegate?.didWrite(data: data, by: self)
        case .sendingResponse:
            writeStatus = .forwarding
            observer?.signal(.readyForForward(self))
            delegate?.didBecomeReadyToForwardWith(socket: self)
        default:
            return
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

        var responseBytes = [UInt8](repeating: 0, count: 10)
        responseBytes[0...3] = [0x05, 0x00, 0x00, 0x01]
        let responseData = Data(bytes: responseBytes)

        writeStatus = .sendingResponse
        write(data: responseData)
    }
}
