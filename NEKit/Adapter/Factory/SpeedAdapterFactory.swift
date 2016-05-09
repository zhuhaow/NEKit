import Foundation

class SpeedAdapterFactory: AdapterFactoryProtocol {
    var adapterFactories: [AdapterFactoryProtocol]!
    
    func canHandle(request: ConnectRequest) -> Bool {
        return true
    }
    
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