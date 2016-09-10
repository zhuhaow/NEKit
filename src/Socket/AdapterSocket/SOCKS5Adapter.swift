import Foundation

public class SOCKS5Adapter: AdapterSocket {
    public let serverHost: String
    public let serverPort: Int

    let helloData = NSData(bytes: ([0x05, 0x01, 0x00] as [UInt8]), length: 3)

    public enum ReadTag: Int {
        case MethodResponse = -20000, ConnectResponseFirstPart, ConnectResponseSecondPart
    }

    public enum WriteTag: Int {
        case Open = -21000, ConnectIPv4, ConnectIPv6, ConnectDomainLength, ConnectPort
    }

    public init(serverHost: String, serverPort: Int) {
        self.serverHost = serverHost
        self.serverPort = serverPort
        super.init()
    }

    public override func openSocketWithRequest(request: ConnectRequest) {
        super.openSocketWithRequest(request)
        do {
            try socket.connectTo(serverHost, port: serverPort, enableTLS: false, tlsSettings: nil)
        } catch {}
    }

    public override func didConnect(socket: RawTCPSocketProtocol) {
        super.didConnect(socket)

        writeData(helloData, withTag: WriteTag.Open.rawValue)
        socket.readDataToLength(2, withTag: ReadTag.MethodResponse.rawValue)
    }

    public override func didReadData(data: NSData, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didReadData(data, withTag: tag, from: socket)

        switch tag {
        case ReadTag.MethodResponse.rawValue:
            if request.isIPv4() {
                var response: [UInt8] = [0x05, 0x01, 0x00, 0x01]
                response += Utils.IP.IPv4ToBytes(request.host)!
                let responseData = NSData(bytes: &response, length: response.count)
                writeData(responseData, withTag: WriteTag.ConnectIPv4.rawValue)
            } else if request.isIPv6() {
                var response: [UInt8] = [0x05, 0x01, 0x00, 0x04]
                response += Utils.IP.IPv6ToBytes(request.host)!
                let responseData = NSData(bytes: &response, length: response.count)
                writeData(responseData, withTag: WriteTag.ConnectIPv6.rawValue)
            } else {
                var response: [UInt8] = [0x05, 0x01, 0x00, 0x03]
                response.append(UInt8(request.host.utf8.count))
                response += [UInt8](request.host.utf8)
                let responseData = NSData(bytes: &response, length: response.count)
                // here we send the domain length and the domain together
                writeData(responseData, withTag: WriteTag.ConnectDomainLength.rawValue)
            }
            var portBytes = Array(Utils.toByteArray(UInt16(request.port)).reverse())
            let portData = NSData(bytes: &portBytes, length: portBytes.count)
            writeData(portData, withTag: WriteTag.ConnectPort.rawValue)
            socket.readDataToLength(5, withTag: ReadTag.ConnectResponseFirstPart.rawValue)
        case ReadTag.ConnectResponseFirstPart.rawValue:
            var readLength = 0
            switch UnsafePointer<UInt8>(data.bytes.advancedBy(3)).memory {
            case 1:
                readLength = 3 + 2
            case 3:
                readLength = Int(UnsafePointer<UInt8>(data.bytes.advancedBy(4)).memory) + 2
            case 4:
                readLength = 15 + 2
            default:
                break
            }
            socket.readDataToLength(readLength, withTag: ReadTag.ConnectResponseSecondPart.rawValue)
        case ReadTag.ConnectResponseSecondPart.rawValue:
            observer?.signal(.ReadyForForward(self))
            delegate?.readyToForward(self)
        default:
            delegate?.didReadData(data, withTag: tag, from: self)
        }
    }

    override public func didWriteData(data: NSData?, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didWriteData(data, withTag: tag, from: socket)

        if WriteTag(rawValue: tag) == nil {
            delegate?.didWriteData(data, withTag: tag, from: self)
        }
    }
}
