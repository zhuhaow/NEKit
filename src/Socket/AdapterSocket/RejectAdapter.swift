import Foundation

public class RejectAdapter: AdapterSocket {
    public let delay: Int

    public init(delay: Int) {
        self.delay = delay
    }

    override func openSocketWithRequest(request: ConnectRequest) {
        super.openSocketWithRequest(request)

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_MSEC) * Int64(delay)), queue) {
            [weak self] in
            self?.disconnect()
        }
    }


    /**
     Disconnect the socket elegantly.
     */
    public override func disconnect() {
        observer?.signal(.DisconnectCalled(self))
        state = .Closed
        delegate?.didDisconnect(self)
    }

    /**
     Disconnect the socket immediately.
     */
    public override func forceDisconnect() {
        observer?.signal(.ForceDisconnectCalled(self))
        state = .Closed
        delegate?.didDisconnect(self)
    }

}
