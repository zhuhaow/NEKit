import Foundation
import CocoaLumberjackSwift

protocol TunnelDelegate : class {
    func tunnelDidClose(tunnel: Tunnel)
}

/// The tunnel forwards data from local to remote and back.
class Tunnel: NSObject, SocketDelegate {
    /// The proxy socket on local.
    var proxySocket: ProxySocket

    /// The adapter socket connected to remote.
    var adapterSocket: AdapterSocket?

    /// The delegate instance.
    weak var delegate: TunnelDelegate?

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

    init(proxySocket: ProxySocket) {
        self.proxySocket = proxySocket
        self.proxySocket.queue = queue
        super.init()
        self.proxySocket.delegate = self
    }

    /**
     Start running the tunnel.
     */
    func openTunnel() {
        proxySocket.openSocket()
    }

    /**
     Close the tunnel.
     */
    func close() {
        if !proxySocket.isDisconnected {
            proxySocket.disconnect()
        }
        if let adapterSocket = adapterSocket {
            if !adapterSocket.isDisconnected {
                adapterSocket.disconnect()
            }
        }
    }

    func didReceiveRequest(request: ConnectRequest, from: ProxySocket) {
        let manager = RuleManager.currentManager
        let factory = manager.match(request)
        adapterSocket = factory.getAdapter(request)
        adapterSocket!.queue = queue
        adapterSocket!.delegate = self
        adapterSocket!.openSocketWithRequest(request)
    }

    func readyToForward(socket: SocketProtocol) {
        readySignal += 1
        if readySignal == 2 {
            proxySocket.readDataWithTag(SocketTag.Forward)
            adapterSocket?.readDataWithTag(SocketTag.Forward)
        }
    }

    func didDisconnect(socket: SocketProtocol) {
        close()
        checkStatus()
    }

    func didReadData(data: NSData, withTag tag: Int, from socket: SocketProtocol) {
        if let _ = socket as? ProxySocket {
            adapterSocket!.writeData(data, withTag: tag)
        } else {
            proxySocket.writeData(data, withTag: tag)
        }
    }

    func didWriteData(data: NSData?, withTag: Int, from socket: SocketProtocol) {
        if let _ = socket as? ProxySocket {
            adapterSocket?.readDataWithTag(SocketTag.Forward)
        } else {
            proxySocket.readDataWithTag(SocketTag.Forward)

        }
    }

    func didConnect(adapterSocket: AdapterSocket, withResponse response: ConnectResponse) {
        proxySocket.respondToResponse(response)
    }

    func updateAdapter(newAdapter: AdapterSocket) {
        adapterSocket = newAdapter
        adapterSocket?.delegate = self
        adapterSocket?.queue = queue
    }

    private func checkStatus() {
        if isClosed {
            delegate?.tunnelDidClose(self)
            delegate = nil
        }
    }
}
