import Foundation

protocol TunnelDelegate : class {
    func tunnelDidClose(tunnel: Tunnel)
}

/// The tunnel forwards data from local to remote and back.
public class Tunnel: NSObject, SocketDelegate {
    /// The proxy socket on local.
    var proxySocket: ProxySocket

    /// The adapter socket connected to remote.
    var adapterSocket: AdapterSocket?

    /// The delegate instance.
    weak var delegate: TunnelDelegate?

    weak var observer: Observer<TunnelEvent>?

    /// Every method call and variable access will be called on this queue.
    var queue = dispatch_queue_create("NEKit.TunnelQueue", DISPATCH_QUEUE_SERIAL) {
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

    override public var description: String {
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
        observer?.signal(.Opened(self))
        proxySocket.openSocket()
        observer?.signal(.Opened(self))
    }

    /**
     Close the tunnel.
     */
    func close() {
        observer?.signal(.CloseCalled(self))
        dispatch_async(queue) {
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
        observer?.signal(.ForceCloseCalled(self))
        dispatch_async(queue) {
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

    public func didReceiveRequest(request: ConnectRequest, from: ProxySocket) {
        observer?.signal(.ReceivedRequest(request, from: from, on: self))
        let manager = RuleManager.currentManager
        let factory = manager.match(request)
        adapterSocket = factory.getAdapter(request)
        adapterSocket!.queue = queue
        adapterSocket!.delegate = self
        adapterSocket!.openSocketWithRequest(request)
    }

    public func readyToForward(socket: SocketProtocol) {
        readySignal += 1
        observer?.signal(.ReceivedReadySignal(socket, currentReady: readySignal, on: self))
        if readySignal == 2 {
            proxySocket.readDataWithTag(SocketTag.Forward)
            adapterSocket?.readDataWithTag(SocketTag.Forward)
        }
    }

    public func didDisconnect(socket: SocketProtocol) {
        close()
        checkStatus()
    }

    public func didReadData(data: NSData, withTag tag: Int, from socket: SocketProtocol) {
        if let socket = socket as? ProxySocket {
            observer?.signal(.ProxySocketReadData(data, tag: tag, from: socket, on: self))
            adapterSocket!.writeData(data, withTag: tag)
        } else if let socket = socket as? AdapterSocket {
            observer?.signal(.AdapterSocketReadData(data, tag: tag, from: socket, on: self))
            proxySocket.writeData(data, withTag: tag)
        }
    }

    public func didWriteData(data: NSData?, withTag: Int, from socket: SocketProtocol) {
        if let socket = socket as? ProxySocket {
            observer?.signal(.ProxySocketWroteData(data, tag: withTag, from: socket, on: self))
            adapterSocket?.readDataWithTag(SocketTag.Forward)
        } else if let socket = socket as? AdapterSocket {
            observer?.signal(.AdapterSocketWroteData(data, tag: withTag, from: socket, on: self))
            proxySocket.readDataWithTag(SocketTag.Forward)
        }
    }

    public func didConnect(adapterSocket: AdapterSocket, withResponse response: ConnectResponse) {
        observer?.signal(.ConnectedToRemote(adapterSocket, withResponse: response, on: self))
        proxySocket.respondToResponse(response)
    }

    public func updateAdapter(newAdapter: AdapterSocket) {
        observer?.signal(.UpdatingAdapterSocket(from: adapterSocket!, to: newAdapter, on: self))

        adapterSocket = newAdapter
        adapterSocket?.delegate = self
        adapterSocket?.queue = queue
    }

    private func checkStatus() {
        if isClosed {
            observer?.signal(.Closed(self))
            delegate?.tunnelDidClose(self)
            delegate = nil
        }
    }
}
