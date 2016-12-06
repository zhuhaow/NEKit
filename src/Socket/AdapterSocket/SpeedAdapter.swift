import Foundation

/// This adpater selects the fastest proxy automatically from a set of proxies.
// TODO: Event support
public class SpeedAdapter: AdapterSocket, SocketDelegate {
    public var adapters: [(AdapterSocket, Int)]!
    var connectingCount = 0
    var pendingCount = 0

    fileprivate var _shouldConnect: Bool = true

    override public var queue: DispatchQueue! {
        didSet {
            for (adapter, _) in adapters {
                adapter.queue = queue
            }
        }
    }

    public override init() {
        super.init()
    }

    override func openSocketWith(request: ConnectRequest) {
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
                    adapter.openSocketWith(request: request)
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
            if adapter.status != .invalid {
                adapter.disconnect()
            }
        }
    }

    override public func forceDisconnect() {
        _shouldConnect = false
        pendingCount = 0
        for (adapter, _) in adapters {
            adapter.delegate = nil
            if adapter.status != .invalid {
                adapter.forceDisconnect()
            }
        }
    }

    public func didConnectWith(adapterSocket socket: AdapterSocket) {}

    public func didBecomeReadyToForwardWith(socket: SocketProtocol) {
        guard let adapterSocket = socket as? AdapterSocket else {
            return
        }

        _shouldConnect = false

        // first we disconnect all other adapter now, and set delegate to nil
        for (adapter, _) in adapters {
            if adapter != adapterSocket {
                adapter.delegate = nil
                if adapter.status != .invalid {
                    adapter.forceDisconnect()
                }
            }
        }

        delegate?.updateAdapterWith(newAdapter: adapterSocket)
        delegate?.didConnectWith(adapterSocket: adapterSocket)
        delegate?.didBecomeReadyToForwardWith(socket: adapterSocket)
        delegate = nil
    }

    public func didDisconnectWith(socket: SocketProtocol) {
        connectingCount -= 1
        if connectingCount == 0 && pendingCount == 0 {
            // failed to connect
            delegate?.didDisconnectWith(socket: self)
        }
    }

    public func didWrite(data: Data?, by: SocketProtocol) {}
    public func didRead(data: Data, from: SocketProtocol) {}
    public func updateAdapterWith(newAdapter: AdapterSocket) {}
    public func didReceive(request: ConnectRequest, from: ProxySocket) {}
}
