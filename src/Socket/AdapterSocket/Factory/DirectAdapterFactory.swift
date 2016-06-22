import Foundation

/// Factory building direct adapter.
class DirectAdapterFactory: AdapterFactoryProtocol {
    /**
     Get a direct adapter.

     - parameter request: The connect request.

     - returns: The built adapter.
     */
    func getAdapter(request: ConnectRequest) -> AdapterSocket {
        return getDirectAdapter()
    }
}
