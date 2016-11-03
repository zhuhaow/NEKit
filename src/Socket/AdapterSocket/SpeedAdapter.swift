import Foundation

/// This adpater selects the fastest proxy automatically from a set of proxies.
// TODO: Event support
open class SpeedAdapter: AdapterSocket, SocketDelegate {
    open var adapters: [(AdapterSocket, Int)]!
    var connectingCount = 0
    var pendingCount = 0

    fileprivate var _shouldConnect: Bool = true

    override open var queue: DispatchQueue! {
        didSet {
            for (adapter, _) in adapters {
                adapter.queue = queue
            }
        }
    }

    public override init() {
        super.init()
    }

    override func openSocketWithRequest(_ request: ConnectRequest) {
        // FIXME: This is a temporary workaround for wechat which uses a wrong way to detect ipv6 by itself.
        if request.isIPv6() {
            disconnect()
            return
        }

        pendingCount = adapters.count
        for (adapter, delay) in adapters {
            queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(NSEC_PER_MSEC) * Int64(delay)) / Double(NSEC_PER_SEC)) {
                if self._shouldConnect {
                    adapter.delegate = self
                    adapter.openSocketWithRequest(request)
                    self.connectingCount += 1
                }
            }
        }
    }

    override open func disconnect() {
        _shouldConnect = false
        pendingCount = 0
        for (adapter, _) in adapters {
            adapter.delegate = nil
            if adapter.state != .invalid {
                adapter.disconnect()
            }
        }
    }

    override open func forceDisconnect() {
        _shouldConnect = false
        pendingCount = 0
        for (adapter, _) in adapters {
            adapter.delegate = nil
            if adapter.state != .invalid {
                adapter.forceDisconnect()
            }
        }
    }

    open func didConnect(_ adapterSocket: AdapterSocket, withResponse response: ConnectResponse) {}

    open func readyToForward(_ socket: SocketProtocol) {
        guard let adapterSocket = socket as? AdapterSocket else {
            return
        }

        _shouldConnect = false

        // first we disconnect all other adapter now, and set delegate to nil
        for (adapter, _) in adapters {
            if adapter != adapterSocket {
                adapter.delegate = nil
                if adapter.state != .invalid {
                    adapter.forceDisconnect()
                }
            }
        }

        delegate?.updateAdapter(adapterSocket)
        delegate?.didConnect(adapterSocket, withResponse: adapterSocket.response)
        delegate?.readyToForward(adapterSocket)
        delegate = nil
    }

    open func didDisconnect(_ socket: SocketProtocol) {
        connectingCount -= 1
        if connectingCount == 0 && pendingCount == 0 {
            // failed to connect
            delegate?.didDisconnect(self)
        }
    }


    open func didWriteData(_ data: Data?, withTag: Int, from: SocketProtocol) {}
    open func didReadData(_ data: Data, withTag: Int, from: SocketProtocol) {}
    open func updateAdapter(_ newAdapter: AdapterSocket) {}
    open func didReceiveRequest(_ request: ConnectRequest, from: ProxySocket) {}
}
