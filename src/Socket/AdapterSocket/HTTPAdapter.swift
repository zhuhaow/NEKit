import Foundation

public enum HTTPAdapterError: ErrorType, CustomStringConvertible {
    case InvalidURL, SerailizationFailure

    public var description: String {
        switch self {
        case .InvalidURL:
            return "Invalid url when connecting through proxy"
        case .SerailizationFailure:
            return "Failed to serialize HTTP CONNECT header"
        }
    }

}

/// This adapter connects to remote host through a HTTP proxy.
public class HTTPAdapter: AdapterSocket {
    /// The host domain of the HTTP proxy.
    let serverHost: String

    /// The port of the HTTP proxy.
    let serverPort: Int

    /// The authentication information for the HTTP proxy.
    let auth: HTTPAuthentication?

    /// Whether the connection to the proxy should be secured or not.
    var secured: Bool

    enum ReadTag: Int {
        case ConnectResponse = 30000
    }
    enum WriteTag: Int {
        case Connect = 40000, HEADER
    }

    init(serverHost: String, serverPort: Int, auth: HTTPAuthentication?) {
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

    override public func didConnect(socket: RawTCPSocketProtocol) {
        super.didConnect(socket)

        guard let url = NSURL(string: "\(request.host):\(request.port)") else {
            observer?.signal(.ErrorOccured(HTTPAdapterError.InvalidURL, on: self))
            disconnect()
            return
        }
        let message = CFHTTPMessageCreateRequest(kCFAllocatorDefault, "CONNECT", url, kCFHTTPVersion1_1).takeRetainedValue()
        if let authData = auth {
            CFHTTPMessageSetHeaderFieldValue(message, "Proxy-Authorization", authData.authString())
        }
        CFHTTPMessageSetHeaderFieldValue(message, "Host", "\(request.host):\(request.port)")
        CFHTTPMessageSetHeaderFieldValue(message, "Content-Length", "0")

        guard let requestData = CFHTTPMessageCopySerializedMessage(message)?.takeRetainedValue() else {
            observer?.signal(.ErrorOccured(HTTPAdapterError.SerailizationFailure, on: self))
            disconnect()
            return
        }

        writeData(requestData, withTag: WriteTag.Connect.rawValue)
        socket.readDataToData(Utils.HTTPData.DoubleCRLF, withTag: ReadTag.ConnectResponse.rawValue)
    }

    override public func didReadData(data: NSData, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didReadData(data, withTag: tag, from: socket)
        if tag == ReadTag.ConnectResponse.rawValue {
            observer?.signal(.ReadyForForward(self))
            delegate?.readyToForward(self)
        } else {
            delegate?.didReadData(data, withTag: tag, from: self)
        }
    }

    override public func didWriteData(data: NSData?, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didWriteData(data, withTag: tag, from: socket)
        if tag != WriteTag.Connect.rawValue {
            delegate?.didWriteData(data, withTag: tag, from: self)
        }
    }
}
