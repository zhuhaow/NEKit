import Foundation

open class RejectAdapterFactory: AdapterFactory {
    open let delay: Int

    public init(delay: Int = Opt.RejectAdapterDefaultDelay) {
        self.delay = delay
    }

    override func getAdapterFor(request: ConnectRequest) -> AdapterSocket {
        return RejectAdapter(delay: delay)
    }
}
