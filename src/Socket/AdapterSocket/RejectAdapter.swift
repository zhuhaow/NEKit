import Foundation

public class RejectAdapter: AdapterSocket {
    open let delay: Int

    public init(delay: Int) {
        self.delay = delay
    }

    override public func openSocketWith(session: ConnectSession) {
        super.openSocketWith(session: session)

        QueueFactory.getQueue().asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(delay)) {
            [weak self] in
            self?.disconnect()
        }
    }

    /**
     Disconnect the socket elegantly.
     */
    public override func disconnect(becauseOf error: Error? = nil) {
        guard !isCancelled else {
            return
        }

        _cancelled = true
        session.disconnected(becauseOf: error, by: .adapter)
        observer?.signal(.disconnectCalled(self))
        _status = .closed
        delegate?.didDisconnectWith(socket: self)
    }

    /**
     Disconnect the socket immediately.
     */
    public override func forceDisconnect(becauseOf error: Error? = nil) {
        guard !isCancelled else {
            return
        }

        _cancelled = true
        session.disconnected(becauseOf: error, by: .adapter)
        observer?.signal(.forceDisconnectCalled(self))
        _status = .closed
        delegate?.didDisconnectWith(socket: self)
    }

}
