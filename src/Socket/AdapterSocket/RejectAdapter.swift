import Foundation

public class RejectAdapter: AdapterSocket {
    open let delay: Int

    public init(delay: Int) {
        self.delay = delay
    }

    override func openSocketWith(request: ConnectRequest) {
        super.openSocketWith(request: request)

        QueueFactory.getQueue().asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.microseconds(delay)) {
            [weak self] in
            self?.disconnect()
        }
    }

    /**
     Disconnect the socket elegantly.
     */
    public override func disconnect() {
        guard !isCancelled else {
            return
        }

        _cancelled = true
        observer?.signal(.disconnectCalled(self))
        _status = .closed
        delegate?.didDisconnectWith(socket: self)
    }

    /**
     Disconnect the socket immediately.
     */
    public override func forceDisconnect() {
        guard !isCancelled else {
            return
        }

        _cancelled = true
        observer?.signal(.forceDisconnectCalled(self))
        _status = .closed
        delegate?.didDisconnectWith(socket: self)
    }

}
