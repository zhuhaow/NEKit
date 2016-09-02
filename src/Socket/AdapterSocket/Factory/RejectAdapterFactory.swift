import Foundation

public class RejectAdapterFactory: AdapterFactory {
    public let delay: Int

    public init(delay: Int = Opt.RejectAdapterDefaultDelay) {
        self.delay = delay
    }

    override func getAdapter(request: ConnectRequest) -> AdapterSocket {
        return RejectAdapter(delay: delay)
    }
}
