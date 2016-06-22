import Foundation
import CocoaLumberjackSwift

class HTTPAdapter: AdapterSocket {
    let serverHost: String
    let serverPort: Int
    let auth: Authentication?
    var secured: Bool

    enum ReadTag: Int {
        case ConnectResponse = 30000
    }
    enum WriteTag: Int {
        case Connect = 40000, HEADER
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
        do {
            try socket.connectTo(serverHost, port: serverPort, enableTLS: secured, tlsSettings: nil)
        } catch {}
    }

    override func didConnect(socket: RawTCPSocketProtocol) {
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

        writeData(requestData, withTag: WriteTag.Connect.rawValue)
        socket.readDataToData(Utils.HTTPData.DoubleCRLF, withTag: ReadTag.ConnectResponse.rawValue)
    }

    override func didReadData(data: NSData, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        if tag == ReadTag.ConnectResponse.rawValue {
            delegate?.readyForForward(self)
        } else {
            super.didReadData(data, withTag: tag, from: socket)
        }
    }

    override func didWriteData(data: NSData?, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        if tag != WriteTag.Connect.rawValue {
            super.didWriteData(data, withTag: tag, from: socket)
        }
    }
}
