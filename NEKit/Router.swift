import Foundation
import CocoaLumberjackSwift

public class Router {
    var IPv4NATRoutes: [UInt16: (UInt32, UInt16)] = [:]
    let interfaceIP: UInt32
    let proxyServerIP: UInt32
    let proxyServerPort: UInt16
    //    let IPv6NATRoutes: [UInt16] = []

    public init(interfaceIP: UInt32, proxyServerIP: UInt32, proxyServerPort: UInt16) {
        self.interfaceIP = interfaceIP
        self.proxyServerIP = proxyServerIP
        self.proxyServerPort = proxyServerPort
    }

    public convenience init(interfaceIP: String, proxyServerIP: String, proxyServerPort: Int) {
        self.init(interfaceIP: Utils.IP.IPv4ToInt(interfaceIP)!, proxyServerIP: Utils.IP.IPv4ToInt(proxyServerIP)!, proxyServerPort: UInt16(proxyServerPort))
    }

    public func rewritePacket(packet: IPPacket) -> IPPacket? {
        // Support only TCP as for now
        guard packet.proto == .TCP else {
            return nil
        }

        guard let packet = packet as? TCPPacket else {
            return nil
        }

        if packet.sourceAddress.inaddr == interfaceIP {
            IPv4NATRoutes[packet.sourcePort] = (packet.destinationAddress.inaddr, packet.destinationPort)
            packet.destinationAddress = IPv4Address(address: proxyServerIP)
            packet.destinationPort = proxyServerPort
            return packet
        } else if packet.destinationAddress.inaddr == interfaceIP {
            guard let (address, port) = IPv4NATRoutes[packet.destinationPort] else {
                return nil
            }
            packet.sourcePort = port
            packet.sourceAddress = IPv4Address(address: address)
            return packet
        } else {
            DDLogError("Does not know how to handle packet: \(packet)")
            return nil
        }
    }

    public func startProcessPacket() {
        readAndProcessPackets()
    }

    func readAndProcessPackets() {
        NetworkInterface.TunnelProvider.packetFlow.readPacketsWithCompletionHandler() {
            var outputPackets = [IPPacket]()
            let packets = $0.0.map { data in
                IPPacket(payload: data)
                }.filter { packet in
                    packet.version == .IPv4
            }
            for packet in packets {
                if let packet = self.rewritePacket(packet) {
                    outputPackets.append(packet)
                }
            }
            let outputData = outputPackets.map { packet in
                packet.payload
            }
            NetworkInterface.TunnelProvider.packetFlow.writePackets(outputData, withProtocols: Array<NSNumber>(count: outputData.count, repeatedValue: 4))
            self.readAndProcessPackets()
        }
    }
}
