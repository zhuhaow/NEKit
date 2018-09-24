import Foundation

open class RejectAdapterFactory: AdapterFactory {
    public let delay: Int

    public init(delay: Int = Opt.RejectAdapterDefaultDelay) {
        self.delay = delay
    }

    override open func getAdapterFor(session: ConnectSession) -> AdapterSocket {
        return RejectAdapter(delay: delay)
    }
}
