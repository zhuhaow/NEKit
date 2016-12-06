import Foundation

/// Factory building speed adapter.
open class SpeedAdapterFactory: AdapterFactory {
    open var adapterFactories: [(AdapterFactory, Int)]!

    public override init() {}

    /**
     Get a speed adapter.

     - parameter request: The connect request.

     - returns: The built adapter.
     */
    override func getAdapterFor(request: ConnectRequest) -> AdapterSocket {
        let adapters = adapterFactories.map { adapterFactory, delay -> (AdapterSocket, Int) in
            let adapter = adapterFactory.getAdapterFor(request: request)
            adapter.socket = RawSocketFactory.getRawSocket()
            return (adapter, delay)
        }
        let speedAdapter = SpeedAdapter()
        speedAdapter.adapters = adapters
        return speedAdapter
    }
}
