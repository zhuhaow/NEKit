import Foundation
import CocoaLumberjackSwift

class SOCKS5ProxySocket: ProxySocket {
    var destinationHost: String!
    var destinationPort: Int!
    
    override func openSocket() {
        super.openSocket()
        socket.readDataToLength(3, withTag: SocketTag.SOCKS5.Open)
    }
    
    override func didReadData(data: NSData, withTag tag: Int, from: RawSocketProtocol) {
        switch tag {
        case SocketTag.SOCKS5.Open:
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
            destinationHost = NSString(bytes: &address, length: Int(INET_ADDRSTRLEN), encoding: NSUTF8StringEncoding) as! String
            socket.readDataToLength(2, withTag: SocketTag.SOCKS5.ConnectPort)
        case SocketTag.SOCKS5.ConnectIPv6:
            var address = [Int8](count: Int(INET6_ADDRSTRLEN), repeatedValue: 0)
            inet_ntop(AF_INET, data.bytes, &address, socklen_t(INET6_ADDRSTRLEN))
            destinationHost = NSString(bytes: &address, length: Int(INET6_ADDRSTRLEN), encoding: NSUTF8StringEncoding) as! String
            socket.readDataToLength(2, withTag: SocketTag.SOCKS5.ConnectPort)
        case SocketTag.SOCKS5.ConnectDomainLength:
            let length :UInt8 = UnsafePointer<UInt8>(data.bytes).memory
            socket.readDataToLength(Int(length), withTag: SocketTag.SOCKS5.ConnectDomain)
        case SocketTag.SOCKS5.ConnectDomain:
            destinationHost = NSString(bytes: data.bytes, length: data.length, encoding: NSUTF8StringEncoding) as! String
            socket.readDataToLength(2, withTag: SocketTag.SOCKS5.ConnectPort)
        case SocketTag.SOCKS5.ConnectPort:
            var rawPort :UInt16 = 0
            data.getBytes(&rawPort, length: sizeof(UInt16))
            destinationPort = Int(NSSwapBigShortToHost(rawPort))
            DDLogInfo("Recieved request to \(destinationHost):\(destinationPort)")
            request = ConnectRequest(host: destinationHost!, port: destinationPort!)
            delegate?.didReceiveRequest(request!, from: self)
        case _ where tag >= 0:
            delegate?.didReadData(data, withTag: tag, from: self)
        default:
            DDLogError("SOCKS5ProxySocket recieved some data with unknown data tag: \(tag)")
            break
        }

    }
    
    override func didWriteData(data: NSData?, withTag tag: Int, from: RawSocketProtocol) {
        if tag >= 0 {
            delegate?.didWriteData(data, withTag: tag, from: self)
        }
        if tag == SocketTag.SOCKS5.ConnectResponse {
            delegate?.readyForForward(self)
        }
    }
    
    override func respondToResponse(response: ConnectResponse) {
        var responseBytes = [UInt8](count: 11, repeatedValue: 0)
        responseBytes[0...3] = [0x05, 0x00, 0x00, 0x01]
        responseBytes[4...7] = [0x7f, 0x00, 0x00, 0x01]
        responseBytes[8...9] = [0x50, 0x66]
        let responseData = NSData(bytes: &responseBytes, length: 10)
        writeData(responseData, withTag: SocketTag.SOCKS5.ConnectResponse)
    }
}