import Foundation
import CocoaLumberjackSwift

public class Router {
    var IPv4NATRoutes: [Port: (IPv4Address, Port)] = [:]
    let interfaceIP: IPv4Address
    let fakeSourceIP: IPv4Address
    let proxyServerIP: IPv4Address
    let proxyServerPort: Port
    //    let IPv6NATRoutes: [UInt16] = []

    public init(interfaceIP: String, fakeSourceIP: String, proxyServerIP: String, proxyServerPort: UInt16) {
        self.interfaceIP = IPv4Address(fromString: interfaceIP)
        self.fakeSourceIP = IPv4Address(fromString: fakeSourceIP)
        self.proxyServerIP = IPv4Address(fromString: proxyServerIP)
        self.proxyServerPort = Port(port: proxyServerPort)
    }

    public func rewritePacket(packet: IPMutablePacket) -> IPMutablePacket? {
        // Support only TCP as for now
        guard packet.proto == .TCP else {
            return nil
        }

        guard let packet = packet as? TCPMutablePacket else {
            return nil
        }

        if packet.sourceAddress == interfaceIP {
            if packet.sourcePort == proxyServerPort {
                guard let (address, port) = IPv4NATRoutes[packet.destinationPort] else {
                    DDLogError("Does not know how to handle packet: \(packet) because can't find entry in NAT table.")
                    return nil
                }
                packet.sourcePort = port
                packet.sourceAddress = address
                packet.destinationAddress = interfaceIP
                return packet
            } else {
                IPv4NATRoutes[packet.sourcePort] = (packet.destinationAddress, packet.destinationPort)
                packet.sourceAddress = fakeSourceIP
                packet.destinationAddress = proxyServerIP
                packet.destinationPort = proxyServerPort
                return packet
            }
        } else {
            DDLogError("Does not know how to handle packet.")
            return nil
        }
    }

    public func startProcessPacket() {
        readAndProcessPackets()
    }

    func readAndProcessPackets() {
        NetworkInterface.TunnelProvider.packetFlow.readPacketsWithCompletionHandler() {
            var outputPackets = [IPMutablePacket]()
            let packets = $0.0.map { data in
                IPMutablePacket(payload: data)
                }.filter { packet in
                    packet.version == .IPv4 && packet.proto == .TCP
                }.map {
                    TCPMutablePacket(payload: $0.payload)
            }
            for packet in packets {
                DDLogVerbose("Received packet of type: \(packet.proto) from \(packet.sourceAddress) to \(packet.destinationAddress)")
                if let packet = self.rewritePacket(packet) {
                    outputPackets.append(packet)
                } else {
                    DDLogVerbose("Failed to rewrite packet \(packet)")
                }
            }

            let outputData = outputPackets.map { packet in
                packet.payload
            }

            if outputData.count > 0 {
                DDLogVerbose("Write out \(outputData.count) packets.")
                NetworkInterface.TunnelProvider.packetFlow.writePackets(outputData, withProtocols: Array<NSNumber>(count: outputData.count, repeatedValue: Int(AF_INET)))
            }
            self.readAndProcessPackets()
        }
    }
}
