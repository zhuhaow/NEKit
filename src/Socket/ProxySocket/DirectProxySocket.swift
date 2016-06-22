import Foundation

/// This class just forwards data directly. It is designed to work with tun2socks.
class DirectProxySocket: ProxySocket {
    /**
     Begin reading and processing data from the socket.

     - note: Since there is nothing to read and process before forwarding data, this just calls `delegate?.didReceiveRequest`.
     */
    override func openSocket() {
        if let address = socket.destinationIPAddress, port = socket.destinationPort {
            request = ConnectRequest(host: address.presentation, port: Int(port.value))
            delegate?.didReceiveRequest(request!, from: self)
        } else {
            forceDisconnect()
        }
    }

    /**
     Response to the `ConnectResponse` from `AdapterSocket` on the other side of the `Tunnel`.

     - parameter response: The response is ignored.
     */
    override func respondToResponse(response: ConnectResponse) {
        delegate?.readyToForward(self)
    }
}
