import Foundation

enum SocketStatus {
    case Invalid, Connecting, Established, Disconnecting, Closed
}

protocol SocketProtocol {
    var socket : RawSocketProtocol! { get }
    var delegate : SocketDelegate? { get set }
    var delegateQueue : dispatch_queue_t! { get set }
    var state : SocketStatus { get set }
}

extension SocketProtocol {
    var disconnected: Bool {
        return state == .Closed || state == .Invalid
    }
    
    func writeData(data: NSData, withTag tag: Int = 0) {
        socket.writeData(data, withTag: tag)
    }
    
//    func readDataToLength(length: Int, withTag tag: Int) {
//        socket.readDataToLength(length, withTag: tag)
//    }
//    
//    func readDataToData(data: NSData, withTag tag: Int) {
//        socket.readDataToData(data, withTag: tag)
//    }
    
    func readDataWithTag(tag: Int = 0) {
        socket.readDataWithTag(tag)
    }
    
    mutating func disconnect() {
        state = .Disconnecting
        socket.disconnect()
    }
    
    mutating func forceDisconnect() {
        state = .Disconnecting
        socket.forceDisconnect()
    }
}

protocol ProxySocketProtocol : SocketProtocol {
    var request: ConnectRequest? { get }
    func openSocket()
    func respondToResponse(response: ConnectResponse)
}

protocol SocketDelegate : class {
    func readyForForward(socket: SocketProtocol)
    func didWriteData(data: NSData?, withTag: Int, from: SocketProtocol)
    func didReadData(data: NSData, withTag: Int, from: SocketProtocol)
    func didDisconnect(socket: SocketProtocol)
    func didReceiveRequest(request: ConnectRequest, from: ProxySocketProtocol)
    func didConnect(adapterSocket: AdapterSocket, withResponse: ConnectResponse)
    func updateAdapter(newAdapter: AdapterSocket)
}

extension SocketDelegate {
    func didReceiveRequest(request: ConnectRequest, from: ProxySocketProtocol) {}
    
    func didConnect(adapterSocket: AdapterSocket, withResponse: ConnectResponse) {}
}