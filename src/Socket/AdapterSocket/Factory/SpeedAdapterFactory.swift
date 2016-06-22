import Foundation

/// Factory building speed adapter.
class SpeedAdapterFactory: AdapterFactoryProtocol {
    var adapterFactories: [AdapterFactoryProtocol]!

    /**
     Get a speed adapter.

     - parameter request: The connect request.

     - returns: The built adapter.
     */
    func getAdapter(request: ConnectRequest) -> AdapterSocket {
        let adapters = adapterFactories.map { adapterFactory -> AdapterSocket in
            let adapter = adapterFactory.getAdapter(request)
            adapter.socket = RawSocketFactory.getRawSocket()
            return adapter
        }
        let speedAdapter = SpeedAdapter()
        speedAdapter.adapters = adapters
        return speedAdapter
    }
}
