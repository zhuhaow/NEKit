import Foundation

/// The base class of adapter factory.
open class AdapterFactory {
    /**
     Build an adapter.

     - parameter request: The connect request.

     - returns: The built adapter.
     */
    func getAdapterFor(request: ConnectRequest) -> AdapterSocket {
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
public class DirectAdapterFactory: AdapterFactory {
    public override init() {}
}
