import Foundation

/// This adpater selects the fastest proxy automatically from a set of proxies.
// TODO: Event support
public class SpeedAdapter: AdapterSocket, SocketDelegate {
    var adapters: [(AdapterSocket, Int)]!
    var connectingCount = 0
    var pendingCount = 0

    private var _shouldConnect: Bool = true

    override public var queue: dispatch_queue_t! {
        didSet {
            for (adapter, _) in adapters {
                adapter.queue = queue
            }
        }
    }

    override init() {
        super.init()
        type = "Speed"
    }

    override func openSocketWithRequest(request: ConnectRequest) {
        pendingCount = adapters.count
        for (adapter, delay) in adapters {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_MSEC) * Int64(delay)), queue) {
                if self._shouldConnect {
                    adapter.delegate = self
                    adapter.openSocketWithRequest(request)
                    self.connectingCount += 1
                }
            }
        }
    }

    override public func disconnect() {
        _shouldConnect = false
        pendingCount = 0
        for (adapter, _) in adapters {
            adapter.delegate = nil
            if adapter.state != .Invalid {
                adapter.disconnect()
            }
        }
    }

    override public func forceDisconnect() {
        _shouldConnect = false
        pendingCount = 0
        for (adapter, _) in adapters {
            adapter.delegate = nil
            if adapter.state != .Invalid {
                adapter.forceDisconnect()
            }
        }
    }

    public func didConnect(adapterSocket: AdapterSocket, withResponse response: ConnectResponse) {}

    public func readyToForward(socket: SocketProtocol) {
        guard let adapterSocket = socket as? AdapterSocket else {
            return
        }

        _shouldConnect = false

        // first we disconnect all other adapter now, and set delegate to nil
        for (adapter, _) in adapters {
            if adapter != adapterSocket {
                adapter.delegate = nil
                if adapter.state != .Invalid {
                    adapter.forceDisconnect()
                }
            }
        }

        delegate?.updateAdapter(adapterSocket)
        delegate?.didConnect(adapterSocket, withResponse: adapterSocket.response)
        delegate?.readyToForward(adapterSocket)
        delegate = nil
    }

    public func didDisconnect(socket: SocketProtocol) {
        connectingCount -= 1
        if connectingCount == 0 && pendingCount == 0 {
            // failed to connect
            delegate?.didDisconnect(self)
        }
    }


    public func didWriteData(data: NSData?, withTag: Int, from: SocketProtocol) {}
    public func didReadData(data: NSData, withTag: Int, from: SocketProtocol) {}
    public func updateAdapter(newAdapter: AdapterSocket) {}
    public func didReceiveRequest(request: ConnectRequest, from: ProxySocket) {}
}
