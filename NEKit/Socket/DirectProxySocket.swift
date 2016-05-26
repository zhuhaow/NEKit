import Foundation

class DirectProxySocket: ProxySocket {
    override func openSocket() {
        request = ConnectRequest(host: socket.destinationIPAddress.presentation, port: socket.destinationPort)
        delegate?.didReceiveRequest(request!, from: self)
    }

    override func respondToResponse(response: ConnectResponse) {
        delegate?.readyForForward(self)
    }
}
