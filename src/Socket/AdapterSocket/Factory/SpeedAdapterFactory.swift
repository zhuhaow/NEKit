import Foundation

/// Factory building speed adapter.
open class SpeedAdapterFactory: AdapterFactory {
    open var adapterFactories: [(AdapterFactory, Int)]!

    public override init() {}

    /**
     Get a speed adapter.

     - parameter session: The connect session.

     - returns: The built adapter.
     */
    override open func getAdapterFor(session: ConnectSession) -> AdapterSocket {
        let adapters = adapterFactories.map { adapterFactory, delay -> (AdapterSocket, Int) in
            let adapter = adapterFactory.getAdapterFor(session: session)
            adapter.socket = RawSocketFactory.getRawSocket()
            return (adapter, delay)
        }
        let speedAdapter = SpeedAdapter()
        speedAdapter.adapters = adapters
        return speedAdapter
    }
}
