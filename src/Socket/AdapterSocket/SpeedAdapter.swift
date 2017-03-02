import Foundation

/// This adpater selects the fastest proxy automatically from a set of proxies.
public class SpeedAdapter: AdapterSocket, SocketDelegate {
    public var adapters: [(AdapterSocket, Int)]!
    var connectingCount = 0
    var pendingCount = 0

    fileprivate var _shouldConnect: Bool = true

    override public func openSocketWith(session: ConnectSession) {
        for (adapter, _) in adapters {
            adapter.observer = nil
        }

        super.openSocketWith(session: session)

        // FIXME: This is a temporary workaround for wechat which uses a wrong way to detect ipv6 by itself.
        if session.isIPv6() {
            _cancelled = true
            // Note `socket` is nil so `didDisconnectWith(socket:)` will never be called.
            didDisconnectWith(socket: self)
            return
        }

        pendingCount = adapters.count
        for (adapter, delay) in adapters {
            QueueFactory.getQueue().asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(delay)) {
                if self._shouldConnect {
                    adapter.delegate = self
                    adapter.openSocketWith(session: session)
                    self.connectingCount += 1
                }
            }
        }
    }

    override public func disconnect(becauseOf error: Error? = nil) {
        super.disconnect(becauseOf: error)

        _shouldConnect = false
        pendingCount = 0
        for (adapter, _) in adapters {
            adapter.delegate = nil
            if adapter.status != .invalid {
                adapter.disconnect(becauseOf: error)
            }
        }
    }

    override public func forceDisconnect(becauseOf error: Error? = nil) {
        super.forceDisconnect(becauseOf: error)

        _shouldConnect = false
        pendingCount = 0
        for (adapter, _) in adapters {
            adapter.delegate = nil
            if adapter.status != .invalid {
                adapter.forceDisconnect(becauseOf: error)
            }
        }
    }

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
        adapterSocket.observer = observer
        observer?.signal(.connected(adapterSocket))
        delegate?.didConnectWith(adapterSocket: adapterSocket)
        observer?.signal(.readyForForward(adapterSocket))
        delegate?.didBecomeReadyToForwardWith(socket: adapterSocket)
        delegate = nil
    }

    public func didDisconnectWith(socket: SocketProtocol) {
        connectingCount -= 1
        if connectingCount <= 0 && pendingCount == 0 {
            // failed to connect
            _status = .closed
            observer?.signal(.disconnected(self))
            delegate?.didDisconnectWith(socket: self)
        }
    }

    public func didConnectWith(adapterSocket socket: AdapterSocket) {}
    public func didWrite(data: Data?, by: SocketProtocol) {}
    public func didRead(data: Data, from: SocketProtocol) {}
    public func updateAdapterWith(newAdapter: AdapterSocket) {}
    public func didReceive(session: ConnectSession, from: ProxySocket) {}
}
