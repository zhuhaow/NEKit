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
public class HTTPAdapter: AdapterSocket {
    enum HTTPAdapterStatus {
        case invalid,
        connecting,
        readingResponse,
        forwarding,
        stopped
    }

    /// The host domain of the HTTP proxy.
    let serverHost: String

    /// The port of the HTTP proxy.
    let serverPort: Int

    /// The authentication information for the HTTP proxy.
    let auth: HTTPAuthentication?

    /// Whether the connection to the proxy should be secured or not.
    var secured: Bool

    var internalStatus: HTTPAdapterStatus = .invalid

    public init(serverHost: String, serverPort: Int, auth: HTTPAuthentication?) {
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.auth = auth
        secured = false
        super.init()
    }

    override public func openSocketWith(session: ConnectSession) {
        super.openSocketWith(session: session)

        guard !isCancelled else {
            return
        }

        do {
            internalStatus = .connecting
            try socket.connectTo(host: serverHost, port: serverPort, enableTLS: secured, tlsSettings: nil)
        } catch {}
    }

    override public func didConnectWith(socket: RawTCPSocketProtocol) {
        super.didConnectWith(socket: socket)

        guard let url = URL(string: "\(session.host):\(session.port)") else {
            observer?.signal(.errorOccured(HTTPAdapterError.invalidURL, on: self))
            disconnect()
            return
        }
        let message = CFHTTPMessageCreateRequest(kCFAllocatorDefault, "CONNECT" as CFString, url as CFURL, kCFHTTPVersion1_1).takeRetainedValue()
        if let authData = auth {
            CFHTTPMessageSetHeaderFieldValue(message, "Proxy-Authorization" as CFString, authData.authString() as CFString?)
        }
        CFHTTPMessageSetHeaderFieldValue(message, "Host" as CFString, "\(session.host):\(session.port)" as CFString?)
        CFHTTPMessageSetHeaderFieldValue(message, "Content-Length" as CFString, "0" as CFString?)

        guard let requestData = CFHTTPMessageCopySerializedMessage(message)?.takeRetainedValue() else {
            observer?.signal(.errorOccured(HTTPAdapterError.serailizationFailure, on: self))
            disconnect()
            return
        }

        internalStatus = .readingResponse
        write(data: requestData as Data)
        socket.readDataTo(data: Utils.HTTPData.DoubleCRLF)
    }

    override public func didRead(data: Data, from socket: RawTCPSocketProtocol) {
        super.didRead(data: data, from: socket)

        switch internalStatus {
        case .readingResponse:
            internalStatus = .forwarding
            observer?.signal(.readyForForward(self))
            delegate?.didBecomeReadyToForwardWith(socket: self)
        case .forwarding:
            observer?.signal(.readData(data, on: self))
            delegate?.didRead(data: data, from: self)
        default:
            return
        }
    }

    override public func didWrite(data: Data?, by socket: RawTCPSocketProtocol) {
        super.didWrite(data: data, by: socket)
        if internalStatus == .forwarding {
            observer?.signal(.wroteData(data, on: self))
            delegate?.didWrite(data: data, by: self)
        }
    }
}
