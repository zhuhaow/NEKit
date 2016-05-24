import Foundation
import CocoaLumberjackSwift
import Zip

protocol TunnelDelegate : class {
    func tunnelDidClose(tunnel: Tunnel)
}

class Tunnel: NSObject, SocketDelegate {
    var proxySocket: ProxySocketProtocol
    var adapterSocket: AdapterSocket?

    weak var delegate: TunnelDelegate?

    var delegateQueue = dispatch_queue_create("TunnelQueue", DISPATCH_QUEUE_SERIAL) {
        didSet {
            self.proxySocket.delegateQueue = delegateQueue
            self.adapterSocket?.delegateQueue = delegateQueue
        }
    }

    var readySignal = 0

    var closed: Bool {
        return proxySocket.disconnected && (adapterSocket?.disconnected ?? true)
    }

    init(proxySocket: ProxySocketProtocol) {
        self.proxySocket = proxySocket
        self.proxySocket.delegateQueue = delegateQueue
        super.init()
        self.proxySocket.delegate = self
    }

    func openTunnel() {
        proxySocket.openSocket()
    }

    func close() {
        if !proxySocket.disconnected {
            proxySocket.disconnect()
        }
        if var adapterSocket = adapterSocket {
            if !adapterSocket.disconnected {
                adapterSocket.disconnect()
            }
        }
    }

    func didReceiveRequest(request: ConnectRequest, from: ProxySocketProtocol) {
        let manager = RuleManager.currentManager
        let factory = manager.match(request)
        adapterSocket = factory.getAdapter(request)
        adapterSocket!.delegateQueue = delegateQueue
        adapterSocket!.delegate = self
        adapterSocket!.openSocketWithRequest(request)
    }

    func readyForForward(socket: SocketProtocol) {
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
        if let _ = socket as? ProxySocketProtocol {
            adapterSocket!.writeData(data, withTag: tag)
        } else {
            proxySocket.writeData(data, withTag: tag)
        }
    }

    func didWriteData(data: NSData?, withTag: Int, from socket: SocketProtocol) {
        if let _ = socket as? ProxySocketProtocol {
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
        adapterSocket?.delegateQueue = delegateQueue
    }

    private func checkStatus() {
        if closed {
            delegate?.tunnelDidClose(self)
            delegate = nil
        }
    }
}
