import Foundation
import Resolver

protocol TunnelDelegate : class {
    func tunnelDidClose(_ tunnel: Tunnel)
}

/// The tunnel forwards data from local to remote and back.
open class Tunnel: NSObject, SocketDelegate {
    /// The proxy socket on local.
    var proxySocket: ProxySocket

    /// The adapter socket connected to remote.
    var adapterSocket: AdapterSocket?

    /// The delegate instance.
    weak var delegate: TunnelDelegate?

    weak var observer: Observer<TunnelEvent>?

    /// Every method call and variable access will be called on this queue.
    var queue = TunnelQueueFactory.getQueue() {
        didSet {
            self.proxySocket.queue = queue
            self.adapterSocket?.queue = queue
        }
    }

    /// Indicating how many socket is ready to forward data.
    var readySignal = 0

    /// If the tunnel is closed, i.e., proxy socket and adapter socket are both disconnected.
    var isClosed: Bool {
        return proxySocket.isDisconnected && (adapterSocket?.isDisconnected ?? true)
    }

    override open var description: String {
        if let adapterSocket = adapterSocket {
            return "<Tunnel proxySocket:\(proxySocket) adapterSocket:\(adapterSocket)>"
        } else {
            return "<Tunnel proxySocket:\(proxySocket)>"
        }
    }

    init(proxySocket: ProxySocket) {
        self.proxySocket = proxySocket
        self.proxySocket.queue = queue
        super.init()
        self.proxySocket.delegate = self

        self.observer = ObserverFactory.currentFactory?.getObserverForTunnel(self)
    }

    /**
     Start running the tunnel.
     */
    func openTunnel() {
        observer?.signal(.opened(self))
        proxySocket.openSocket()
        observer?.signal(.opened(self))
    }

    /**
     Close the tunnel.
     */
    func close() {
        observer?.signal(.closeCalled(self))
        queue.async {
            if !self.proxySocket.isDisconnected {
                self.proxySocket.disconnect()
            }
            if let adapterSocket = self.adapterSocket {
                if !adapterSocket.isDisconnected {
                    adapterSocket.disconnect()
                }
            }
        }
    }

    func forceClose() {
        observer?.signal(.forceCloseCalled(self))
        queue.async {
            if !self.proxySocket.isDisconnected {
                self.proxySocket.forceDisconnect()
            }
            if let adapterSocket = self.adapterSocket {
                if !adapterSocket.isDisconnected {
                    adapterSocket.forceDisconnect()
                }
            }
        }
    }

    open func didReceiveRequest(_ request: ConnectRequest, from: ProxySocket) {
        observer?.signal(.receivedRequest(request, from: from, on: self))

        if Opt.resolveDNSInAdvance && !request.isIP() {
            _ = Resolver.resolve(hostname: request.host) { [weak self] resolver, err in
                self?.queue.async {
                    if err != nil {
                        request.ipAddress = ""
                    } else {
                        request.ipAddress = (resolver?.ipv4Result.first)!
                    }
                    self?.openAdapter(for: request)
                }
            }
        } else {
            openAdapter(for: request)
        }
    }

    func openAdapter(for request: ConnectRequest) {
        let manager = RuleManager.currentManager
        let factory = manager.match(request)!
        adapterSocket = factory.getAdapter(request)
        adapterSocket!.queue = queue
        adapterSocket!.delegate = self
        adapterSocket!.openSocketWithRequest(request)
    }

    open func readyToForward(_ socket: SocketProtocol) {
        readySignal += 1
        observer?.signal(.receivedReadySignal(socket, currentReady: readySignal, on: self))
        if readySignal == 2 {
            proxySocket.readDataWithTag(SocketTag.Forward)
            adapterSocket?.readDataWithTag(SocketTag.Forward)
        }
    }

    open func didDisconnect(_ socket: SocketProtocol) {
        close()
        checkStatus()
    }

    open func didReadData(_ data: Data, withTag tag: Int, from socket: SocketProtocol) {
        if let socket = socket as? ProxySocket {
            observer?.signal(.proxySocketReadData(data, tag: tag, from: socket, on: self))
            adapterSocket!.writeData(data, withTag: tag)
        } else if let socket = socket as? AdapterSocket {
            observer?.signal(.adapterSocketReadData(data, tag: tag, from: socket, on: self))
            proxySocket.writeData(data, withTag: tag)
        }
    }

    open func didWriteData(_ data: Data?, withTag: Int, from socket: SocketProtocol) {
        if let socket = socket as? ProxySocket {
            observer?.signal(.proxySocketWroteData(data, tag: withTag, from: socket, on: self))
            adapterSocket?.readDataWithTag(SocketTag.Forward)
        } else if let socket = socket as? AdapterSocket {
            observer?.signal(.adapterSocketWroteData(data, tag: withTag, from: socket, on: self))
            proxySocket.readDataWithTag(SocketTag.Forward)
        }
    }

    open func didConnect(_ adapterSocket: AdapterSocket, withResponse response: ConnectResponse) {
        observer?.signal(.connectedToRemote(adapterSocket, withResponse: response, on: self))
        proxySocket.respondToResponse(response)
    }

    open func updateAdapter(_ newAdapter: AdapterSocket) {
        observer?.signal(.updatingAdapterSocket(from: adapterSocket!, to: newAdapter, on: self))

        adapterSocket = newAdapter
        adapterSocket?.delegate = self
        adapterSocket?.queue = queue
    }

    fileprivate func checkStatus() {
        if isClosed {
            observer?.signal(.closed(self))
            delegate?.tunnelDidClose(self)
            delegate = nil
        }
    }
}
