import Foundation

class DirectProxySocket: ProxySocket {
    override func openSocket() {
        if let address = socket.destinationIPAddress, port = socket.destinationPort {
            request = ConnectRequest(host: address.presentation, port: port)
            delegate?.didReceiveRequest(request!, from: self)
        } else {
            forceDisconnect()
        }
    }

    override func respondToResponse(response: ConnectResponse) {
        delegate?.readyForForward(self)
    }
}
