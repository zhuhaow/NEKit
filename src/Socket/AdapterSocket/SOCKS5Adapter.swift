import Foundation

open class SOCKS5Adapter: AdapterSocket {
    open let serverHost: String
    open let serverPort: Int

    let helloData = Data(bytes: UnsafePointer<UInt8>(([0x05, 0x01, 0x00] as [UInt8])), count: 3)

    public enum ReadTag: Int {
        case methodResponse = -20000, connectResponseFirstPart, connectResponseSecondPart
    }

    public enum WriteTag: Int {
        case open = -21000, connectIPv4, connectIPv6, connectDomainLength, connectPort
    }

    public init(serverHost: String, serverPort: Int) {
        self.serverHost = serverHost
        self.serverPort = serverPort
        super.init()
    }

    open override func openSocketWithRequest(_ request: ConnectRequest) {
        super.openSocketWithRequest(request)
        do {
            try socket.connectTo(serverHost, port: serverPort, enableTLS: false, tlsSettings: nil)
        } catch {}
    }

    open override func didConnect(_ socket: RawTCPSocketProtocol) {
        super.didConnect(socket)

        writeData(helloData, withTag: WriteTag.open.rawValue)
        socket.readDataToLength(2, withTag: ReadTag.methodResponse.rawValue)
    }

    open override func didReadData(_ data: Data, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didReadData(data, withTag: tag, from: socket)

        switch tag {
        case ReadTag.methodResponse.rawValue:
            if request.isIPv4() {
                var response: [UInt8] = [0x05, 0x01, 0x00, 0x01]
                response += Utils.IP.IPv4ToBytes(request.host)!
                let responseData = Data(bytes: response)
                writeData(responseData, withTag: WriteTag.connectIPv4.rawValue)
            } else if request.isIPv6() {
                var response: [UInt8] = [0x05, 0x01, 0x00, 0x04]
                response += Utils.IP.IPv6ToBytes(request.host)!
                let responseData = Data(bytes: response)
                writeData(responseData, withTag: WriteTag.connectIPv6.rawValue)
            } else {
                var response: [UInt8] = [0x05, 0x01, 0x00, 0x03]
                response.append(UInt8(request.host.utf8.count))
                response += [UInt8](request.host.utf8)
                let responseData = Data(bytes: response)
                // here we send the domain length and the domain together
                writeData(responseData, withTag: WriteTag.connectDomainLength.rawValue)
            }
            let portBytes: [UInt8] = Utils.toByteArray(UInt16(request.port)).reversed()
            let portData = Data(bytes: portBytes)
            writeData(portData, withTag: WriteTag.connectPort.rawValue)
            socket.readDataToLength(5, withTag: ReadTag.connectResponseFirstPart.rawValue)
        case ReadTag.connectResponseFirstPart.rawValue:
            var readLength = 0
            data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) in
                switch ptr.advanced(by: 3).pointee {
                case 1:
                    readLength = 3 + 2
                case 3:
                    readLength = Int(ptr.advanced(by: 1).pointee) + 2
                case 4:
                    readLength = 15 + 2
                default:
                    break
                }
            }
            socket.readDataToLength(readLength, withTag: ReadTag.connectResponseSecondPart.rawValue)
        case ReadTag.connectResponseSecondPart.rawValue:
            observer?.signal(.readyForForward(self))
            delegate?.readyToForward(self)
        default:
            delegate?.didReadData(data, withTag: tag, from: self)
        }
    }

    override open func didWriteData(_ data: Data?, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didWriteData(data, withTag: tag, from: socket)

        if WriteTag(rawValue: tag) == nil {
            delegate?.didWriteData(data, withTag: tag, from: self)
        }
    }
}
