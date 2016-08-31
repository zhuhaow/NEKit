import Foundation

/// The base class of adapter factory.
public class AdapterFactory {
    /**
     Build an adapter.

     - parameter request: The connect request.

     - returns: The built adapter.
     */
    func getAdapter(request: ConnectRequest) -> AdapterSocket {
        return getDirectAdapter()
    }

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

/// Factory building direct adapters.
///
/// - note: This is needed since we need to identify direct adapter factory.
public class DirectAdapterFactory: AdapterFactory {}
