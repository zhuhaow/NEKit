import Foundation

/// The protocol defines the adapter factory.
protocol AdapterFactoryProtocol: class {
    /**
     Build an adapter.

     - parameter request: The connect request.

     - returns: The built adapter.
     */
    func getAdapter(request: ConnectRequest) -> AdapterSocket
}

extension AdapterFactoryProtocol {
    /**
     Helper method to get a `DirectAdapter`.

     - returns: A direct adapter.
     */
    func getDirectAdapter() -> AdapterSocket {
        let adapter = DirectAdapter()
        adapter.socket = RawSocketFactory.getRawSocket()
        return adapter
    }
}
