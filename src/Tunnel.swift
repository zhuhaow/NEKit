import Foundation
import CocoaLumberjackSwift

protocol TunnelDelegate : class {
    func tunnelDidClose(tunnel: Tunnel)
}

class Tunnel: NSObject, SocketDelegate {
    var proxySocket: ProxySocket
    var adapterSocket: AdapterSocket?

    weak var delegate: TunnelDelegate?

    var delegateQueue = dispatch_queue_create("TunnelQueue", DISPATCH_QUEUE_SERIAL) {
        didSet {
            self.proxySocket.queue = delegateQueue
            self.adapterSocket?.queue = delegateQueue
        }
    }

    var readySignal = 0

    var closed: Bool {
        return proxySocket.isDisconnected && (adapterSocket?.isDisconnected ?? true)
    }

    init(proxySocket: ProxySocket) {
        self.proxySocket = proxySocket
        self.proxySocket.queue = delegateQueue
        super.init()
        self.proxySocket.delegate = self
    }

    func openTunnel() {
        proxySocket.openSocket()
    }

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
        adapterSocket!.queue = delegateQueue
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
        adapterSocket?.queue = delegateQueue
    }

    private func checkStatus() {
        if closed {
            delegate?.tunnelDidClose(self)
            delegate = nil
        }
    }
}
