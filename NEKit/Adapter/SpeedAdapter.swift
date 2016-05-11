import Foundation

class SpeedAdapter: AdapterSocket, SocketDelegate {
    var adapters: [AdapterSocket]!
    var connectingCount = 0

    override var delegateQueue: dispatch_queue_t! {
        didSet {
            for adapter in adapters {
                adapter.delegateQueue = delegateQueue
            }
        }
    }

    override func openSocketWithRequest(request: ConnectRequest) {
        connectingCount = adapters.count
        for adapter in adapters {
            adapter.delegate = self
            adapter.openSocketWithRequest(request)
        }
    }

    func disconnect() {
        for var adapter in adapters {
            adapter.delegate = nil
            adapter.disconnect()
        }
        // no need to wait for anything since this is only called when the other side is closed before we make any successful connection.
        delegate?.didDisconnect(self)
    }

    func forceDisconnect() {
        for var adapter in adapters {
            adapter.delegate = nil
            adapter.forceDisconnect()
        }
        delegate?.didDisconnect(self)
    }

    func didConnect(adapterSocket: AdapterSocket, withResponse response: ConnectResponse) {}

    func readyForForward(socket: SocketProtocol) {
        let adapterSocket = socket as! AdapterSocket
        // first we disconnect all other adapter now, and set delegate to nil
        for var adapter in adapters {
            if adapter != adapterSocket {
                adapter.delegate = nil
                adapter.forceDisconnect()
            }
        }

        delegate?.updateAdapter(adapterSocket)
        delegate?.didConnect(adapterSocket, withResponse: adapterSocket.response)
        delegate?.readyForForward(adapterSocket)
    }

    func didDisconnect(socket: SocketProtocol) {
        connectingCount -= 1
        if connectingCount == 0 {
            // failed to connect
            delegate?.didDisconnect(self)
        }
    }


    func didWriteData(data: NSData?, withTag: Int, from: SocketProtocol) {}
    func didReadData(data: NSData, withTag: Int, from: SocketProtocol) {}
    func updateAdapter(newAdapter: AdapterSocket) {}
}
