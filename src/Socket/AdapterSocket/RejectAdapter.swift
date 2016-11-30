import Foundation

open class RejectAdapter: AdapterSocket {
    open let delay: Int

    public init(delay: Int) {
        self.delay = delay
    }

    override func openSocketWithRequest(_ request: ConnectRequest) {
        super.openSocketWithRequest(request)

        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(NSEC_PER_MSEC) * Int64(delay)) / Double(NSEC_PER_SEC)) {
            [weak self] in
            self?.disconnect()
        }
    }

    /**
     Disconnect the socket elegantly.
     */
    open override func disconnect() {
        observer?.signal(.disconnectCalled(self))
        status = .closed
        delegate?.didDisconnect(self)
    }

    /**
     Disconnect the socket immediately.
     */
    open override func forceDisconnect() {
        observer?.signal(.forceDisconnectCalled(self))
        status = .closed
        delegate?.didDisconnect(self)
    }

}
