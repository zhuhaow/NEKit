import Foundation
import CocoaLumberjackSwift

public enum IPVersion: UInt8 {
    case iPv4 = 4, iPv6 = 6
}

public enum TransportProtocol: UInt8 {
    case icmp = 1, tcp = 6, udp = 17
}

/// The class to process and build IP packet.
///
/// - note: Only IPv4 is supported as of now.
open class IPPacket {
    /**
     Get the version of the IP Packet without parsing the whole packet.
     
     - parameter data: The data containing the whole IP packet.
     
     - returns: The version of the packet. Returns `nil` if failed to parse the packet.
     */
    open static func peekIPVersion(_ data: Data) -> IPVersion? {
        guard data.count >= 20 else {
            return nil
        }

        let version = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee >> 4
        return IPVersion(rawValue: version)
    }

    /**
     Get the protocol of the IP Packet without parsing the whole packet.
     
     - parameter data: The data containing the whole IP packet.
     
     - returns: The protocol of the packet. Returns `nil` if failed to parse the packet.
     */
    open static func peekProtocol(_ data: Data) -> TransportProtocol? {
        guard data.count >= 20 else {
            return nil
        }

        return TransportProtocol(rawValue: (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).advanced(by: 9).pointee)
    }

    /**
     Get the source IP address of the IP packet without parsing the whole packet.
     
     - parameter data: The data containing the whole IP packet.
     
     - returns: The source IP address of the packet. Returns `nil` if failed to parse the packet.
     */
    open static func peekSourceAddress(_ data: Data) -> IPAddress? {
        guard data.count >= 20 else {
            return nil
        }

        return IPAddress(fromBytesInNetworkOrder: (data as NSData).bytes.advanced(by: 12))
    }

    /**
     Get the destination IP address of the IP packet without parsing the whole packet.
     
     - parameter data: The data containing the whole IP packet.
     
     - returns: The destination IP address of the packet. Returns `nil` if failed to parse the packet.
     */
    open static func peekDestinationAddress(_ data: Data) -> IPAddress? {
        guard data.count >= 20 else {
            return nil
        }

        return IPAddress(fromBytesInNetworkOrder: (data as NSData).bytes.advanced(by: 16))
    }

    /**
     Get the source port of the IP packet without parsing the whole packet.
     
     - parameter data: The data containing the whole IP packet.
     
     - returns: The source IP address of the packet. Returns `nil` if failed to parse the packet.
     
     - note: Only TCP and UDP packet has port field.
     */
    open static func peekSourcePort(_ data: Data) -> Port? {
        guard let proto = peekProtocol(data) else {
            return nil
        }

        guard proto == .tcp || proto == .udp else {
            return nil
        }

        let headerLength = Int((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee & 0x0F * 4)

        // Make sure there are bytes for source and destination bytes.
        guard data.count > headerLength + 4 else {
            return nil
        }

        return Port(bytesInNetworkOrder: (data as NSData).bytes.advanced(by: headerLength))
    }

    /**
     Get the destination port of the IP packet without parsing the whole packet.
     
     - parameter data: The data containing the whole IP packet.
     
     - returns: The destination IP address of the packet. Returns `nil` if failed to parse the packet.
     
     - note: Only TCP and UDP packet has port field.
     */
    open static func peekDestinationPort(_ data: Data) -> Port? {
        guard let proto = peekProtocol(data) else {
            return nil
        }

        guard proto == .tcp || proto == .udp else {
            return nil
        }

        let headerLength = Int((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee & 0x0F * 4)

        // Make sure there are bytes for source and destination bytes.
        guard data.count > headerLength + 4 else {
            return nil
        }

        return Port(bytesInNetworkOrder: (data as NSData).bytes.advanced(by: headerLength + 2))
    }

    /// The version of the current IP packet.
    open var version: IPVersion = .iPv4

    /// The length of the IP packet header.
    open var headerLength: UInt8 = 20

    /// This contains the DSCP and ECN of the IP packet.
    ///
    /// - note: Since we can not send custom IP packet out with NetworkExtension, this is useless and simply ignored.
    open var tos: UInt8 = 0

    /// This should be the length of the datagram.
    /// This value is not read from header since NEPacketTunnelFlow has already taken care of it for us.
    open var totalLength: UInt16 {
        return UInt16(packetData.count)
    }

    /// Identification of the current packet.
    ///
    /// - note: Since we do not support fragment, this is ignored and always will be zero.
    /// - note: Theoratically, this should be a sequentially increasing number. It probably will be implemented.
    var identification: UInt16 = 0

    /// Offset of the current packet.
    ///
    /// - note: Since we do not support fragment, this is ignored and always will be zero.
    var offset: UInt16 = 0

    /// TTL of the packet.
    var TTL: UInt8 = 64

    /// Source IP address.
    var sourceAddress: IPAddress!

    /// Destination IP address.
    var destinationAddress: IPAddress!

    /// Transport protocol of the packet.
    var transportProtocol: TransportProtocol!

    /// Parser to parse the payload in IP packet.
    var protocolParser: TransportProtocolParserProtocol!

    /// The data representing the packet.
    var packetData: Data!

    /**
     Initailize a new instance to build IP packet.
     */
    init() {}

    /**
     Initailize an `IPPacket` with data.
     
     - parameter packetData: The data containing a whole packet.
     */
    init?(packetData: Data) {
        // no need to validate the packet.

        self.packetData = packetData

        let scanner = BinaryDataScanner(data: packetData, littleEndian: false)

        let vhl = scanner.readByte()!
        guard let v = IPVersion(rawValue: vhl >> 4) else {
            DDLogError("Got unknown ip packet version \(vhl >> 4)")
            return nil
        }
        version = v
        headerLength = vhl & 0x0F * 4

        guard packetData.count >= Int(headerLength) else {
            return nil
        }

        tos = scanner.readByte()!

        guard totalLength == scanner.read16()! else {
            DDLogError("Packet length mismatches from header.")
            return nil
        }

        identification = scanner.read16()!
        offset = scanner.read16()!
        TTL = scanner.readByte()!

        guard let proto = TransportProtocol(rawValue: scanner.readByte()!) else {
            DDLogWarn("Get unsupported packet protocol.")
            return nil
        }
        transportProtocol = proto

        // ignore checksum
        _ = scanner.read16()!

        switch version {
        case .iPv4:
            sourceAddress = IPAddress(ipv4InNetworkOrder: CFSwapInt32(scanner.read32()!))
            destinationAddress = IPAddress(ipv4InNetworkOrder: CFSwapInt32(scanner.read32()!))
        default:
            // IPv6 is not supported yet.
            DDLogWarn("IPv6 is not supported yet.")
            return nil
        }

        switch transportProtocol! {
        case .udp:
            guard let parser = UDPProtocolParser(packetData: packetData, offset: Int(headerLength)) else {
                return nil
            }
            self.protocolParser = parser
        default:
            DDLogError("Can not parse packet header of type \(transportProtocol) yet")
            return nil
        }
    }

    func computePseudoHeaderChecksum() -> UInt32 {
        var result: UInt32 = 0
        if let address = sourceAddress {
            result += address.UInt32InNetworkOrder! >> 16 + address.UInt32InNetworkOrder! & 0xFFFF
        }
        if let address = destinationAddress {
            result += address.UInt32InNetworkOrder! >> 16 + address.UInt32InNetworkOrder! & 0xFFFF
        }
        result += UInt32(transportProtocol.rawValue) << 8
        result += CFSwapInt32(UInt32(protocolParser.bytesLength))
        return result
    }

    func buildPacket() {
        packetData = NSMutableData(length: Int(headerLength) + protocolParser.bytesLength) as Data!

        // set header
        setPayloadWithUInt8(headerLength / 4 + version.rawValue << 4, at: 0)
        setPayloadWithUInt8(tos, at: 1)
        setPayloadWithUInt16(totalLength, at: 2)
        setPayloadWithUInt16(identification, at: 4)
        setPayloadWithUInt16(offset, at: 6)
        setPayloadWithUInt8(TTL, at: 8)
        setPayloadWithUInt8(transportProtocol.rawValue, at: 9)
        // clear checksum bytes
        resetPayloadAt(10, length: 2)
        setPayloadWithUInt32(sourceAddress.UInt32InNetworkOrder!, at: 12, swap: false)
        setPayloadWithUInt32(destinationAddress.UInt32InNetworkOrder!, at: 16, swap: false)

        // let TCP or UDP packet build
        protocolParser.packetData = packetData
        protocolParser.offset = Int(headerLength)
        protocolParser.buildSegment(computePseudoHeaderChecksum())
        packetData = protocolParser.packetData

        setPayloadWithUInt16(Checksum.computeChecksum(packetData, from: 0, to: Int(headerLength)), at: 10, swap: false)
    }

    func setPayloadWithUInt8(_ value: UInt8, at: Int) {
        var v = value
        withUnsafeBytes(of: &v) {
            packetData.replaceSubrange(at..<at+1, with: $0)
        }
    }

    func setPayloadWithUInt16(_ value: UInt16, at: Int, swap: Bool = true) {
        var v: UInt16
        if swap {
            v = CFSwapInt16HostToBig(value)
        } else {
            v = value
        }
        withUnsafeBytes(of: &v) {
            packetData.replaceSubrange(at..<at+2, with: $0)
        }
    }

    func setPayloadWithUInt32(_ value: UInt32, at: Int, swap: Bool = true) {
        var v: UInt32
        if swap {
            v = CFSwapInt32HostToBig(value)
        } else {
            v = value
        }
        withUnsafeBytes(of: &v) {
            packetData.replaceSubrange(at..<at+4, with: $0)
        }
    }

    func setPayloadWithData(_ data: Data, at: Int, length: Int? = nil, from: Int = 0) {
        var length = length
        if length == nil {
            length = data.count - from
        }
        packetData.replaceSubrange(at..<at+length!, with: data)
    }

    func resetPayloadAt(_ at: Int, length: Int) {
        packetData.resetBytes(in: at..<at+length)
    }

}
