import Foundation
import Resolver

protocol TunnelDelegate : class {
    func tunnelDidClose(_ tunnel: Tunnel)
}

/// The tunnel forwards data between local and remote.
public class Tunnel: NSObject, SocketDelegate {

    /// The status of `Tunnel`.
    public enum TunnelStatus: CustomStringConvertible {

        case invalid, readingRequest, waitingToBeReady, forwarding, closing, closed

        public var description: String {
            switch self {
            case .invalid:
                return "invalid"
            case .readingRequest:
                return "reading request"
            case .waitingToBeReady:
                return "waiting to be ready"
            case .forwarding:
                return "forwarding"
            case .closing:
                return "closing"
            case .closed:
                return "closed"
            }
        }
    }

    /// The proxy socket.
    var proxySocket: ProxySocket

    /// The adapter socket connecting to remote.
    var adapterSocket: AdapterSocket?

    /// The delegate instance.
    weak var delegate: TunnelDelegate?

    weak var observer: Observer<TunnelEvent>?

    /// Indicating how many socket is ready to forward data.
    private var readySignal = 0

    /// If the tunnel is closed, i.e., proxy socket and adapter socket are both disconnected.
    var isClosed: Bool {
        return proxySocket.isDisconnected && (adapterSocket?.isDisconnected ?? true)
    }

    fileprivate var _cancelled: Bool = false
    fileprivate var _stopForwarding = false
    public var isCancelled: Bool {
        return _cancelled
    }

    fileprivate var _status: TunnelStatus = .invalid
    public var status: TunnelStatus {
        return _status
    }

    public var statusDescription: String {
        return status.description
    }

    override public var description: String {
        if let adapterSocket = adapterSocket {
            return "<Tunnel proxySocket:\(proxySocket) adapterSocket:\(adapterSocket)>"
        } else {
            return "<Tunnel proxySocket:\(proxySocket)>"
        }
    }

    init(proxySocket: ProxySocket) {
        self.proxySocket = proxySocket
        super.init()
        self.proxySocket.delegate = self

        self.observer = ObserverFactory.currentFactory?.getObserverForTunnel(self)
    }

    /**
     Start running the tunnel.
     */
    func openTunnel() {
        guard !self.isCancelled else {
            return
        }

        self.proxySocket.openSocket()
        self._status = .readingRequest
        self.observer?.signal(.opened(self))
    }

    /**
     Close the tunnel elegantly.
     */
    func close() {
        observer?.signal(.closeCalled(self))

        guard !self.isCancelled else {
            return
        }

        self._cancelled = true
        self._status = .closing

        if !self.proxySocket.isDisconnected {
            self.proxySocket.disconnect()
        }
        if let adapterSocket = self.adapterSocket {
            if !adapterSocket.isDisconnected {
                adapterSocket.disconnect()
            }
        }
    }

    /// Close the tunnel immediately.
    ///
    /// - note: This method is thread-safe.
    func forceClose() {
        observer?.signal(.forceCloseCalled(self))

        guard !self.isCancelled else {
            return
        }

        self._cancelled = true
        self._status = .closing
        self._stopForwarding = true

        if !self.proxySocket.isDisconnected {
            self.proxySocket.forceDisconnect()
        }
        if let adapterSocket = self.adapterSocket {
            if !adapterSocket.isDisconnected {
                adapterSocket.forceDisconnect()
            }
        }
    }

    public func didReceive(request: ConnectRequest, from: ProxySocket) {
        guard !isCancelled else {
            return
        }

        _status = .waitingToBeReady
        observer?.signal(.receivedRequest(request, from: from, on: self))

        if !request.isIP() {
            _ = Resolver.resolve(hostname: request.host, timeout: Opt.DNSTimeout) { [weak self] resolver, err in
                QueueFactory.getQueue().async {
                    if err != nil {
                        request.ipAddress = ""
                    } else {
                        request.ipAddress = (resolver?.ipv4Result.first)!
                    }
                    self?.openAdapter(for: request)
                }
            }
        } else {
            request.ipAddress = request.host
            openAdapter(for: request)
        }
    }

    fileprivate func openAdapter(for request: ConnectRequest) {
        guard !isCancelled else {
            return
        }

        let manager = RuleManager.currentManager
        let factory = manager.match(request)!
        adapterSocket = factory.getAdapterFor(request: request)
        adapterSocket!.delegate = self
        adapterSocket!.openSocketWith(request: request)
    }

    public func didBecomeReadyToForwardWith(socket: SocketProtocol) {
        guard !isCancelled else {
            return
        }

        readySignal += 1
        observer?.signal(.receivedReadySignal(socket, currentReady: readySignal, on: self))

        defer {
            if let socket = socket as? AdapterSocket {
                proxySocket.respondTo(adapter: socket)
            }
        }
        if readySignal == 2 {
            _status = .forwarding
            proxySocket.readData()
            adapterSocket?.readData()
        }
    }

    public func didDisconnectWith(socket: SocketProtocol) {
        if !isCancelled {
            _stopForwarding = true
            close()
        }
        checkStatus()
    }

    public func didRead(data: Data, from socket: SocketProtocol) {
        if let socket = socket as? ProxySocket {
            observer?.signal(.proxySocketReadData(data, from: socket, on: self))

            guard !isCancelled else {
                return
            }
            adapterSocket!.write(data: data)
        } else if let socket = socket as? AdapterSocket {
            observer?.signal(.adapterSocketReadData(data, from: socket, on: self))

            guard !isCancelled else {
                return
            }
            proxySocket.write(data: data)
        }
    }

    public func didWrite(data: Data?, by socket: SocketProtocol) {
        if let socket = socket as? ProxySocket {
            observer?.signal(.proxySocketWroteData(data, by: socket, on: self))

            guard !isCancelled else {
                return
            }
            QueueFactory.getQueue().asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.microseconds(Opt.forwardReadInterval)) { [weak self] in
                self?.adapterSocket?.readData()
            }
        } else if let socket = socket as? AdapterSocket {
            observer?.signal(.adapterSocketWroteData(data, by: socket, on: self))

            guard !isCancelled else {
                return
            }

            QueueFactory.getQueue().asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.microseconds(Opt.forwardReadInterval)) { [weak self] in
                self?.proxySocket.readData()
            }
        }
    }

    public func didConnectWith(adapterSocket: AdapterSocket) {
        guard !isCancelled else {
            return
        }

        observer?.signal(.connectedToRemote(adapterSocket, on: self))
    }

    public func updateAdapterWith(newAdapter: AdapterSocket) {
        guard !isCancelled else {
            return
        }

        observer?.signal(.updatingAdapterSocket(from: adapterSocket!, to: newAdapter, on: self))

        adapterSocket = newAdapter
        adapterSocket?.delegate = self
    }

    fileprivate func checkStatus() {
        if isClosed {
            _status = .closed
            observer?.signal(.closed(self))
            delegate?.tunnelDidClose(self)
            delegate = nil
        }
    }
}
