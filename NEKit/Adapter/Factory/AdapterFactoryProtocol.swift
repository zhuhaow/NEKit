import Foundation

protocol AdapterFactoryProtocol: class {
    func canHandle(request: ConnectRequest) -> Bool
    func getAdapter(request: ConnectRequest) -> AdapterSocket
}

extension AdapterFactoryProtocol {
    func getDirectAdapter() -> AdapterSocket {
        let adapter = DirectAdapter()
        adapter.socket = GCDSocket()
        return adapter
    }
}