import Foundation

struct ConnectInfo: Hashable {
    let sourceAddress: IPv4Address
    let sourcePort: Port
    let destinationAddress: IPv4Address
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
    private var activeSockets: [ConnectInfo: NWUDPSocket] = [:]
    public var outputFunc: (([NSData], [NSNumber]) -> ())!

    private let queue: dispatch_queue_t = dispatch_queue_create("NEKit.UDPDirectStack.SocketArrayQueue", DISPATCH_QUEUE_SERIAL)

    private let cleanUpTimer: dispatch_source_t

    init() {
        cleanUpTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
        dispatch_source_set_timer(cleanUpTimer, DISPATCH_TIME_NOW, NSEC_PER_SEC * UInt64(Opt.UDPSocketActiveCheckInterval), NSEC_PER_SEC * 30)
        dispatch_source_set_event_handler(cleanUpTimer) {
            [weak self] in
            self?.cleanUpTimeoutSocket()
        }
        dispatch_resume(cleanUpTimer)
    }

    /**
     Input a packet into the stack.

     - note: Only process IPv4 UDP packet as of now.

     - parameter packet:  The IP packet.
     - parameter version: The version of the IP packet, i.e., AF_INET, AF_INET6.

     - returns: If the stack accepts in this packet. If the packet is accepted, then it won't be processed by other IP stacks.
     */
    public func inputPacket(packet: NSData, version: NSNumber?) -> Bool {
        if let version = version {
            // we do not process IPv6 packets now
            if version.intValue == AF_INET6 {
                return false
            }
        }
        if IPPacket.peekProtocol(packet) == .UDP {
            input(packet)
            return true
        }
        return false
    }

    private func input(packetData: NSData) {
        guard let packet = IPPacket(packetData: packetData) else {
            return
        }

        let (_, socket) = findOrCreateSocketForPacket(packet)
        // swiftlint:disable:next force_cast
        let payload = (packet.protocolParser as! UDPProtocolParser).payload
        socket.writeData(payload)
    }

    private func findSocket(connectInfo connectInfo: ConnectInfo?, socket: NWUDPSocket?) -> (ConnectInfo, NWUDPSocket)? {
        var result: (ConnectInfo, NWUDPSocket)?

        dispatch_sync(queue) {
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

            guard let index = self.activeSockets.indexOf({ connectInfo, sock in
                return socket === sock
            }) else {
                result = nil
                return
            }

            result = self.activeSockets[index]
        }
        return result
    }

    private func findOrCreateSocketForPacket(packet: IPPacket) -> (ConnectInfo, NWUDPSocket) {
        // swiftlint:disable:next force_cast
        let udpParser = packet.protocolParser as! UDPProtocolParser
        let connectInfo = ConnectInfo(sourceAddress: packet.sourceAddress, sourcePort: udpParser.sourcePort, destinationAddress: packet.destinationAddress, destinationPort: udpParser.destinationPort)

        if let (_, socket) = findSocket(connectInfo: connectInfo, socket: nil) {
            return (connectInfo, socket)
        }

        let udpSocket = NWUDPSocket(host: connectInfo.destinationAddress.presentation, port: connectInfo.destinationPort.intValue)
        udpSocket.delegate = self

        dispatch_sync(queue) {
            self.activeSockets[connectInfo] = udpSocket
        }
        return (connectInfo, udpSocket)
    }

    // This shoule be called by the timer, so is already on `queue`.
    private func cleanUpTimeoutSocket() {
        for (connectInfo, socket) in activeSockets {
            if (socket.lastActive.dateByAddingTimeInterval(NSTimeInterval(Opt.UDPSocketActiveTimeout)).compare(NSDate()) == .OrderedAscending) {
                activeSockets.removeValueForKey(connectInfo)
            }
        }
    }

    func didReceiveData(data: NSData, from: NWUDPSocket) {
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
        packet.buildPacket()

        outputFunc([packet.packetData], [NSNumber(int: AF_INET)])
    }
}
