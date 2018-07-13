import Foundation

public class SOCKS5Adapter: AdapterSocket {
    enum SOCKS5AdapterStatus {
        case invalid,
        connecting,
        authenticating,
        readingMethodResponse,
        readingResponseFirstPart,
        readingResponseSecondPart,
        forwarding
    }
    public let serverHost: String
    public let serverPort: Int
    public let userName: String?
    public let passWord: String?
    let isNeedAuthen:Bool
    
    
    var internalStatus: SOCKS5AdapterStatus = .invalid
    
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
        self.userName  = ""
        self.passWord = ""
        self.isNeedAuthen = false
        super.init()
    }
    public init(serverHost: String, serverPort: Int ,userName:String,passWord:String) {
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.isNeedAuthen = true
        self.userName  = userName
        self.passWord = passWord
        
        //        NSLog("---socks5用户名：%@---",userName)
        //
        //        NSLog("---socks5密码：%@---",passWord)
        super.init()
    }
    public override func openSocketWith(session: ConnectSession) {
        super.openSocketWith(session: session)
        
        guard !isCancelled else {
            return
        }
        
        do {
            internalStatus = .connecting
            try socket.connectTo(host: serverHost, port: serverPort, enableTLS: false, tlsSettings: nil)
        } catch {}
    }
    
    public override func didConnectWith(socket: RawTCPSocketProtocol) {
        super.didConnectWith(socket: socket)
        
        if isNeedAuthen {
            
            let authenhelloData = Data(bytes: UnsafePointer<UInt8>(([0x05, 0x01, 0x02] as [UInt8])), count: 3)
            write(data: authenhelloData)
            internalStatus = .authenticating
            socket.readDataTo(length: 2)
            NSLog("---进入socks5验证环节---")
            
        }else{
            write(data: helloData)
            internalStatus = .readingMethodResponse
            socket.readDataTo(length: 2)
            
            NSLog("---进入socks5直连环节---")
        }
    }
    
    public override func didRead(data: Data, from socket: RawTCPSocketProtocol) {
        super.didRead(data: data, from: socket)
        
        if isNeedAuthen{
            switch internalStatus {
            case .authenticating:
                //                let dataarr = [UInt8](data)
                //                NSLog("---收到socks验证authenticating %@---",dataarr)
                let data = userName!.data(using: .utf8)!
                let usernameData = [UInt8](data)
                //            let usernameData :[UInt8] = [UInt8](userName!.utf8)
                //        let usernameData = username.data(using: .utf8)!
                let data1 = passWord!.data(using: .utf8)!
                let passwordData = [UInt8](data1)
                //            let passwordData :[UInt8] = [UInt8](passWord!.utf8)
                //        let passwordData = password.data(using: .utf8)!
                let usernameLength = UInt8(usernameData.count)
                let passwordLength = UInt8(passwordData.count)
                var authenData =  Data()
                authenData.append(contentsOf: [0x01])
                authenData.append(contentsOf: [usernameLength])
                authenData.append(contentsOf: usernameData)
                authenData.append(contentsOf: [passwordLength])
                authenData.append(contentsOf: passwordData)
                print(authenData)
                write(data: authenData)
                //                let dataarr1 = [UInt8](authenData)
                //                NSLog("---发送socks5验证 %@---",dataarr1)
                
                internalStatus = .readingMethodResponse
                socket.readDataTo(length: 2)
                
                
            case .readingMethodResponse:
                
                //                let dataarr = [UInt8](data)
                //                NSLog("---收到socks验证readingMethodResponse %@---",dataarr)
                var response: [UInt8]
                if session.isIPv4() {
                    response = [0x05, 0x01, 0x00, 0x01]
                    let address = IPAddress(fromString: session.host)!
                    response += [UInt8](address.dataInNetworkOrder)
                } else if session.isIPv6() {
                    response = [0x05, 0x01, 0x00, 0x04]
                    let address = IPAddress(fromString: session.host)!
                    response += [UInt8](address.dataInNetworkOrder)
                } else {
                    response = [0x05, 0x01, 0x00, 0x03]
                    response.append(UInt8(session.host.utf8.count))
                    response += [UInt8](session.host.utf8)
                }
                
                let portBytes: [UInt8] = Utils.toByteArray(UInt16(session.port)).reversed()
                response.append(contentsOf: portBytes)
                write(data: Data(bytes: response))
                
                
                //                NSLog("---发送socks5 %@---",response)
                if isNeedAuthen {
                    internalStatus = .readingResponseFirstPart
                }else{
                    internalStatus = .readingResponseFirstPart
                }
                socket.readDataTo(length: 5)
            case .readingResponseFirstPart:
                //                let dataarr = [UInt8](data)
                //                NSLog("---收到socks验证readingResponseFirstPart %@---",dataarr)
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
                internalStatus = .readingResponseSecondPart
                socket.readDataTo(length: readLength)
            case .readingResponseSecondPart:
                
                //                let dataarr = [UInt8](data)
                //                NSLog("---收到socks验证readingResponseSecondPart %@---",dataarr)
                internalStatus = .forwarding
                observer?.signal(.readyForForward(self))
                delegate?.didBecomeReadyToForwardWith(socket: self)
            case .forwarding:
                
                //                let dataarr = [UInt8](data)
                //                NSLog("---收到socks验证forwarding %@---",dataarr)
                delegate?.didRead(data: data, from: self)
            default:
                return
            }
        }else{
            switch internalStatus {
            case .readingMethodResponse:
                var response: [UInt8]
                if session.isIPv4() {
                    response = [0x05, 0x01, 0x00, 0x01]
                    let address = IPAddress(fromString: session.host)!
                    response += [UInt8](address.dataInNetworkOrder)
                } else if session.isIPv6() {
                    response = [0x05, 0x01, 0x00, 0x04]
                    let address = IPAddress(fromString: session.host)!
                    response += [UInt8](address.dataInNetworkOrder)
                } else {
                    response = [0x05, 0x01, 0x00, 0x03]
                    response.append(UInt8(session.host.utf8.count))
                    response += [UInt8](session.host.utf8)
                }
                
                let portBytes: [UInt8] = Utils.toByteArray(UInt16(session.port)).reversed()
                response.append(contentsOf: portBytes)
                write(data: Data(bytes: response))
                
                internalStatus = .readingResponseFirstPart
                socket.readDataTo(length: 5)
            case .readingResponseFirstPart:
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
                internalStatus = .readingResponseSecondPart
                socket.readDataTo(length: readLength)
            case .readingResponseSecondPart:
                internalStatus = .forwarding
                observer?.signal(.readyForForward(self))
                delegate?.didBecomeReadyToForwardWith(socket: self)
            case .forwarding:
                delegate?.didRead(data: data, from: self)
            default:
                return
            }
        }
        
    }
    
    override open func didWrite(data: Data?, by socket: RawTCPSocketProtocol) {
        super.didWrite(data: data, by: socket)
        
        if internalStatus == .forwarding {
            delegate?.didWrite(data: data, by: self)
        }
    }
}
