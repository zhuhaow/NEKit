import Foundation
import CocoaLumberjackSwift

class HTTPAdapter : AdapterSocket {
    let serverHost: String
    let serverPort: Int
    let auth: Authentication?
    var secured: Bool
    
    enum ReadTag :Int {
        case CONNECT_RESPONSE = 30000
    }
    enum WriteTag :Int {
        case CONNECT = 40000, HEADER
    }
    
    init(serverHost: String, serverPort: Int, auth: Authentication?) {
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.auth = auth
        secured = false
        super.init()
    }
    
    override func openSocketWithRequest(request: ConnectRequest) {
        super.openSocketWithRequest(request)
        socket.connectTo(serverHost, port: serverPort, enableTLS: secured, tlsSettings: nil)
    }
    
    override func didConnect(socket: RawSocketProtocol) {
        super.didConnect(socket)
        
        guard let url = NSURL(string: "\(request.host):\(request.port)") else {
            DDLogError("Invalid url when connecting through HTTP(S) proxy: \(request.host):\(request.port)")
            delegate?.didDisconnect(self)
            return
        }
        let message = CFHTTPMessageCreateRequest(kCFAllocatorDefault, "CONNECT", url, kCFHTTPVersion1_1).takeRetainedValue()
        if let authData = auth {
            CFHTTPMessageSetHeaderFieldValue(message, "Proxy-Authorization", authData.authString())
        }
        CFHTTPMessageSetHeaderFieldValue(message, "Host", "\(request.host):\(request.port)")
        CFHTTPMessageSetHeaderFieldValue(message, "Content-Length", "0")
        
        guard let requestData = CFHTTPMessageCopySerializedMessage(message)?.takeRetainedValue() else {
            DDLogError("Failed to serialize HTTP CONNECT header when connecting to \(request.host):\(request.port)")
            delegate?.didDisconnect(self)
            return
        }
        
        writeData(requestData, withTag: WriteTag.CONNECT.rawValue)
        readDataToData(Utils.HTTPData.DoubleCRLF, withTag: ReadTag.CONNECT_RESPONSE.rawValue)
    }
    
    override func didReadData(data: NSData, withTag tag: Int, from socket: RawSocketProtocol) {
        if tag == ReadTag.CONNECT_RESPONSE.rawValue {
            delegate?.readyForForward(self)
        } else {
            super.didReadData(data, withTag: tag, from: socket)
        }
    }
    
    override func didWriteData(data: NSData?, withTag tag: Int, from socket: RawSocketProtocol) {
        if tag != WriteTag.CONNECT.rawValue {
            super.didWriteData(data, withTag: tag, from: socket)
        }
    }
}