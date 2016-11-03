import Foundation

public enum HTTPAdapterError: Error, CustomStringConvertible {
    case invalidURL, serailizationFailure

    public var description: String {
        switch self {
        case .invalidURL:
            return "Invalid url when connecting through proxy"
        case .serailizationFailure:
            return "Failed to serialize HTTP CONNECT header"
        }
    }

}

/// This adapter connects to remote host through a HTTP proxy.
open class HTTPAdapter: AdapterSocket {
    /// The host domain of the HTTP proxy.
    let serverHost: String

    /// The port of the HTTP proxy.
    let serverPort: Int

    /// The authentication information for the HTTP proxy.
    let auth: HTTPAuthentication?

    /// Whether the connection to the proxy should be secured or not.
    var secured: Bool

    enum ReadTag: Int {
        case connectResponse = 30000
    }
    enum WriteTag: Int {
        case connect = 40000, header
    }

    public init(serverHost: String, serverPort: Int, auth: HTTPAuthentication?) {
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.auth = auth
        secured = false
        super.init()
    }

    override func openSocketWithRequest(_ request: ConnectRequest) {
        super.openSocketWithRequest(request)
        do {
            try socket.connectTo(serverHost, port: serverPort, enableTLS: secured, tlsSettings: nil)
        } catch {}
    }

    override open func didConnect(_ socket: RawTCPSocketProtocol) {
        super.didConnect(socket)

        guard let url = URL(string: "\(request.host):\(request.port)") else {
            observer?.signal(.errorOccured(HTTPAdapterError.invalidURL, on: self))
            disconnect()
            return
        }
        let message = CFHTTPMessageCreateRequest(kCFAllocatorDefault, "CONNECT" as CFString, url as CFURL, kCFHTTPVersion1_1).takeRetainedValue()
        if let authData = auth {
            CFHTTPMessageSetHeaderFieldValue(message, "Proxy-Authorization" as CFString, authData.authString() as CFString?)
        }
        CFHTTPMessageSetHeaderFieldValue(message, "Host" as CFString, "\(request.host):\(request.port)" as CFString?)
        CFHTTPMessageSetHeaderFieldValue(message, "Content-Length" as CFString, "0" as CFString?)

        guard let requestData = CFHTTPMessageCopySerializedMessage(message)?.takeRetainedValue() else {
            observer?.signal(.errorOccured(HTTPAdapterError.serailizationFailure, on: self))
            disconnect()
            return
        }

        writeData(requestData as Data, withTag: WriteTag.connect.rawValue)
        socket.readDataToData(Utils.HTTPData.DoubleCRLF, withTag: ReadTag.connectResponse.rawValue)
    }

    override open func didReadData(_ data: Data, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didReadData(data, withTag: tag, from: socket)
        if tag == ReadTag.connectResponse.rawValue {
            observer?.signal(.readyForForward(self))
            delegate?.readyToForward(self)
        } else {
            delegate?.didReadData(data, withTag: tag, from: self)
        }
    }

    override open func didWriteData(_ data: Data?, withTag tag: Int, from socket: RawTCPSocketProtocol) {
        super.didWriteData(data, withTag: tag, from: socket)
        if tag != WriteTag.connect.rawValue {
            delegate?.didWriteData(data, withTag: tag, from: self)
        }
    }
}
