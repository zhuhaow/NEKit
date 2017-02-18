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
    
    /// Remember all of the adapter sockets connecting to remote
    /// One proxy socket can have multiple adapters by different host and port
    var adaptersByHostAndPort: [String: AdapterSocket] = [String: AdapterSocket]()
    
    /// The delegate instance.
    weak var delegate: TunnelDelegate?
    
    weak var observer: Observer<TunnelEvent>?
    
    /// Indicating how many socket is ready to forward data.
    private var readySignal = 0
    
    /// Indicating how many socket is ready to forward data for each adapter.
    private var readySignalByHostAndPort: [String: Int] = [String: Int]()
    
    /// If the tunnel is closed, i.e., proxy socket and adapter socket are both disconnected.
    var isClosed: Bool {
        var isDisconnected: Bool = true
        var a: AdapterSocket?
        for adapter in self.adaptersByHostAndPort.values {
            a = adapter
            isDisconnected = isDisconnected && (a?.isDisconnected ?? true)
        }
        return proxySocket.isDisconnected && (isDisconnected)
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
        
        for adapter in self.adaptersByHostAndPort.values {
            self.adapterSocket = adapter
            if let adapterSocket = self.adapterSocket {
                if !adapterSocket.isDisconnected {
                    adapterSocket.disconnect()
                }
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
        
        for adapter in self.adaptersByHostAndPort.values {
            self.adapterSocket = adapter
            if let adapterSocket = self.adapterSocket {
                if !adapterSocket.isDisconnected {
                    adapterSocket.forceDisconnect()
                }
            }
        }
    }
    
    public func didReceive(session: ConnectSession, from: ProxySocket) {
        guard !isCancelled else {
            return
        }
        
        if readySignalByHostAndPort[session.host+":"+String(session.port)] == nil {
            readySignalByHostAndPort[session.host+":"+String(session.port)] = 0
        }
        
        _status = .waitingToBeReady
        observer?.signal(.receivedRequest(session, from: from, on: self))
        
        if !session.isIP() {
            _ = Resolver.resolve(hostname: session.host, timeout: Opt.DNSTimeout) { [weak self] resolver, err in
                QueueFactory.getQueue().async {
                    if err != nil {
                        session.ipAddress = ""
                    } else {
                        session.ipAddress = (resolver?.ipv4Result.first)!
                    }
                    self?.openAdapter(for: session)
                }
            }
        } else {
            session.ipAddress = session.host
            openAdapter(for: session)
        }
    }
    
    fileprivate func openAdapter(for session: ConnectSession) {
        guard !isCancelled else {
            return
        }
        
        let manager = RuleManager.currentManager
        let factory = manager.match(session)!
        adapterSocket = factory.getAdapterFor(session: session)
        adapterSocket!.delegate = self
        self.adaptersByHostAndPort[session.host+":"+String(session.port)] = adapterSocket
        adapterSocket!.openSocketWith(session: session)
    }
    
    public func didBecomeReadyToForwardWith(session: ConnectSession, socket: SocketProtocol) {
        guard !isCancelled else {
            return
        }
        
        readySignal = readySignalByHostAndPort[session.host+":"+String(session.port)]!
        readySignal += 1
        readySignalByHostAndPort[session.host+":"+String(session.port)] = readySignal
        
        observer?.signal(.receivedReadySignal(socket, currentReady: readySignal, on: self))
        
        defer {
            if let socket = socket as? AdapterSocket {
                proxySocket.respondTo(adapter: socket)
            }
        }
        if readySignal == 2 {
            _status = .forwarding
            proxySocket.readData()
            self.adapterSocket = self.adaptersByHostAndPort[session.host+":"+String(session.port)]
            adapterSocket?.readData()
        }
    }
    
    public func didDisconnectWith(session: ConnectSession, socket: SocketProtocol) {
        if !isCancelled {
            _stopForwarding = true
            close()
        }
        checkStatus()
    }
    
    public func didRead(session: ConnectSession, data: Data, from socket: SocketProtocol) {
        if let socket = socket as? ProxySocket {
            observer?.signal(.proxySocketReadData(data, from: socket, on: self))
            
            guard !isCancelled else {
                return
            }
            self.adapterSocket = self.adaptersByHostAndPort[session.host+":"+String(session.port)]
            adapterSocket!.write(data: data)
        } else if let socket = socket as? AdapterSocket {
            observer?.signal(.adapterSocketReadData(data, from: socket, on: self))
            
            guard !isCancelled else {
                return
            }
            proxySocket.write(data: data)
        }
    }
    
    public func didWrite(session: ConnectSession, data: Data?, by socket: SocketProtocol) {
        if let socket = socket as? ProxySocket {
            observer?.signal(.proxySocketWroteData(data, by: socket, on: self))
            
            guard !isCancelled else {
                return
            }
            QueueFactory.getQueue().asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.microseconds(Opt.forwardReadInterval)) { [weak self] in
                self?.adapterSocket = self?.adaptersByHostAndPort[session.host+":"+String(session.port)]
                self?.adapterSocket?.readData()
            }
        } else if let socket = socket as? AdapterSocket {
            observer?.signal(.adapterSocketWroteData(data, by: socket, on: self))
            
            guard !isCancelled else {
                return
            }
            
            proxySocket.readData()
        }
    }
    
    public func didConnectWith(session: ConnectSession, adapterSocket: AdapterSocket) {
        guard !isCancelled else {
            return
        }
        
        observer?.signal(.connectedToRemote(adapterSocket, on: self))
    }
    
    public func updateAdapterWith(session: ConnectSession, newAdapter: AdapterSocket) {
        guard !isCancelled else {
            return
        }
        
        observer?.signal(.updatingAdapterSocket(from: adapterSocket!, to: newAdapter, on: self))
        
        adapterSocket = newAdapter
        adapterSocket?.delegate = self
        
        self.adaptersByHostAndPort[session.host+":"+String(session.port)] = self.adapterSocket
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
