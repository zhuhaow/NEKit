import Foundation

struct ConnectInfo: Hashable {
    let sourceAddress: IPAddress
    let sourcePort: Port
    let destinationAddress: IPAddress
    let destinationPort: Port

    var hashValue: Int {
        return sourceAddress.hashValue &+ sourcePort.hashValue &+ destinationAddress.hashValue &+ destinationPort.hashValue
    }
}

func == (left: ConnectInfo, right: ConnectInfo) -> Bool {
    return left.destinationAddress == right.destinationAddress &&
        left.destinationPort == right.destinationPort &&
        left.sourceAddress == right.sourceAddress &&
        left.sourcePort == right.sourcePort
}

/// This stack tranmits UDP packets directly.
public class UDPDirectStack: IPStackProtocol, NWUDPSocketDelegate {
    fileprivate var activeSockets: [ConnectInfo: NWUDPSocket] = [:]
    public var outputFunc: (([Data], [NSNumber]) -> Void)!

    fileprivate let queue: DispatchQueue = DispatchQueue(label: "NEKit.UDPDirectStack.SocketArrayQueue", attributes: [])

    public init() {}
    
    /**
     Input a packet into the stack.

     - note: Only process IPv4 UDP packet as of now.

     - parameter packet:  The IP packet.
     - parameter version: The version of the IP packet, i.e., AF_INET, AF_INET6.

     - returns: If the stack accepts in this packet. If the packet is accepted, then it won't be processed by other IP stacks.
     */
    public func input(packet: Data, version: NSNumber?) -> Bool {
        if let version = version {
            // we do not process IPv6 packets now
            if version.int32Value == AF_INET6 {
                return false
            }
        }
        if IPPacket.peekProtocol(packet) == .udp {
            input(packet)
            return true
        }
        return false
    }
    
    public func start() {
        
    }

    public func stop() {
        queue.async {
            for socket in self.activeSockets.values {
                socket.disconnect()
            }
            self.activeSockets = [:]
        }
    }

    fileprivate func input(_ packetData: Data) {
        guard let packet = IPPacket(packetData: packetData) else {
            return
        }

        guard let (_, socket) = findOrCreateSocketForPacket(packet) else {
            return
        }

        // swiftlint:disable:next force_cast
        let payload = (packet.protocolParser as! UDPProtocolParser).payload
        socket.write(data: payload!)
    }

    fileprivate func findSocket(connectInfo: ConnectInfo?, socket: NWUDPSocket?) -> (ConnectInfo, NWUDPSocket)? {
        var result: (ConnectInfo, NWUDPSocket)?

        queue.sync {
            if connectInfo != nil {
                guard let sock = self.activeSockets[connectInfo!] else {
                    result = nil
                    return
                }
                result = (connectInfo!, sock)
                return
            }

            guard let socket = socket else {
                result = nil
                return
            }

            guard let index = self.activeSockets.index(where: { _, sock in
                return socket === sock
            }) else {
                result = nil
                return
            }

            result = self.activeSockets[index]
        }
        return result
    }

    fileprivate func findOrCreateSocketForPacket(_ packet: IPPacket) -> (ConnectInfo, NWUDPSocket)? {
        // swiftlint:disable:next force_cast
        let udpParser = packet.protocolParser as! UDPProtocolParser
        let connectInfo = ConnectInfo(sourceAddress: packet.sourceAddress, sourcePort: udpParser.sourcePort, destinationAddress: packet.destinationAddress, destinationPort: udpParser.destinationPort)

        if let (_, socket) = findSocket(connectInfo: connectInfo, socket: nil) {
            return (connectInfo, socket)
        }

        guard let session = ConnectSession(ipAddress: connectInfo.destinationAddress, port: connectInfo.destinationPort) else {
            return nil
        }

        guard let udpSocket = NWUDPSocket(host: session.host, port: session.port) else {
            return nil
        }

        udpSocket.delegate = self

        queue.sync {
            self.activeSockets[connectInfo] = udpSocket
        }
        return (connectInfo, udpSocket)
    }

    public func didReceive(data: Data, from: NWUDPSocket) {
        guard let (connectInfo, _) = findSocket(connectInfo: nil, socket: from) else {
            return
        }

        let packet = IPPacket()
        packet.sourceAddress = connectInfo.destinationAddress
        packet.destinationAddress = connectInfo.sourceAddress
        let udpParser = UDPProtocolParser()
        udpParser.sourcePort = connectInfo.destinationPort
        udpParser.destinationPort = connectInfo.sourcePort
        udpParser.payload = data
        packet.protocolParser = udpParser
        packet.transportProtocol = .udp
        packet.buildPacket()

        outputFunc([packet.packetData], [NSNumber(value: AF_INET as Int32)])
    }
    
    public func didCancel(socket: NWUDPSocket) {
        guard let (info, _) = findSocket(connectInfo: nil, socket: socket) else {
            return
        }
        
        activeSockets.removeValue(forKey: info)
    }
}
