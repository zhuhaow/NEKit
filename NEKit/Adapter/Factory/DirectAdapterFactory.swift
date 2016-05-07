import Foundation

class DirectAdapterFactory : AdapterFactoryProtocol {
    func canHandle(request: ConnectRequest) -> Bool {
        return true
    }
    
    func getAdapter(request: ConnectRequest) -> AdapterSocket {
        return getDirectAdapter()
    }
}