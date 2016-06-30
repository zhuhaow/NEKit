import Foundation
import CocoaLumberjackSwift

public enum IPVersion: UInt8 {
    case IPv4 = 4, IPv6 = 6
}

public enum TransportProtocol: UInt8 {
    case ICMP = 1, TCP = 6, UDP = 17
}

/// The class to process and build IP packet.
///
/// - note: Only IPv4 is supported as of now.
public class IPPacket {
    /**
     Get the version of the IP Packet without parsing the whole packet.

     - parameter data: The data containing the whole IP packet.

     - returns: The version of the packet. Returns `nil` if failed to parse the packet.
     */
    public static func peekIPVersion(data: NSData) -> IPVersion? {
        guard data.length >= 20 else {
            return nil
        }

        let version = UnsafePointer<UInt8>(data.bytes).memory >> 4
        return IPVersion(rawValue: version)
    }

    /**
     Get the protocol of the IP Packet without parsing the whole packet.

     - parameter data: The data containing the whole IP packet.

     - returns: The protocol of the packet. Returns `nil` if failed to parse the packet.
     */
    public static func peekProtocol(data: NSData) -> TransportProtocol? {
        guard data.length >= 20 else {
            return nil
        }

        return TransportProtocol(rawValue: UnsafePointer<UInt8>(data.bytes).advancedBy(9).memory)
    }

    /**
     Get the source IP address of the IP packet without parsing the whole packet.

     - parameter data: The data containing the whole IP packet.

     - returns: The source IP address of the packet. Returns `nil` if failed to parse the packet.
     */
    public static func peekSourceAddress(data: NSData) -> IPv4Address? {
        guard data.length >= 20 else {
            return nil
        }

        return IPv4Address(fromBytesInNetworkOrder: data.bytes.advancedBy(12))
    }

    /**
     Get the destination IP address of the IP packet without parsing the whole packet.

     - parameter data: The data containing the whole IP packet.

     - returns: The destination IP address of the packet. Returns `nil` if failed to parse the packet.
     */
    public static func peekDestinationAddress(data: NSData) -> IPv4Address? {
        guard data.length >= 20 else {
            return nil
        }

        return IPv4Address(fromBytesInNetworkOrder: data.bytes.advancedBy(16))
    }

    /**
     Get the source port of the IP packet without parsing the whole packet.

     - parameter data: The data containing the whole IP packet.

     - returns: The source IP address of the packet. Returns `nil` if failed to parse the packet.

     - note: Only TCP and UDP packet has port field.
     */
    public static func peekSourcePort(data: NSData) -> Port? {
        guard let proto = peekProtocol(data) else {
            return nil
        }

        guard proto == .TCP || proto == .UDP else {
            return nil
        }

        let headerLength = Int(UnsafePointer<UInt8>(data.bytes).memory & 0x0F * 4)

        // Make sure there are bytes for source and destination bytes.
        guard data.length > headerLength + 4 else {
            return nil
        }

        return Port(bytesInNetworkOrder: data.bytes.advancedBy(headerLength))
    }

    /**
     Get the destination port of the IP packet without parsing the whole packet.

     - parameter data: The data containing the whole IP packet.

     - returns: The destination IP address of the packet. Returns `nil` if failed to parse the packet.

     - note: Only TCP and UDP packet has port field.
     */
    public static func peekDestinationPort(data: NSData) -> Port? {
        guard let proto = peekProtocol(data) else {
            return nil
        }

        guard proto == .TCP || proto == .UDP else {
            return nil
        }

        let headerLength = Int(UnsafePointer<UInt8>(data.bytes).memory & 0x0F * 4)

        // Make sure there are bytes for source and destination bytes.
        guard data.length > headerLength + 4 else {
            return nil
        }

        return Port(bytesInNetworkOrder: data.bytes.advancedBy(headerLength + 2))
    }


    /// The version of the current IP packet.
    public var version: IPVersion = .IPv4

    /// The length of the IP packet header.
    public var headerLength: UInt8 = 20

    /// This contains the DSCP and ECN of the IP packet.
    ///
    /// - note: Since we can not send custom IP packet out with NetworkExtension, this is useless and simply ignored.
    public var tos: UInt8 = 0

    /// This should be the length of the datagram.
    /// This value is not read from header since NEPacketTunnelFlow has already taken care of it for us.
    public var totalLength: UInt16 {
        get {
            return UInt16(packetData.length)
        }
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
    var sourceAddress: IPv4Address!

    /// Destination IP address.
    var destinationAddress: IPv4Address!

    /// Transport protocol of the packet.
    var transportProtocol: TransportProtocol!

    /// Parser to parse the payload in IP packet.
    var protocolParser: TransportProtocolParserProtocol!

    /// The data representing the packet.
    var packetData: NSData!

    /// Helper to cast the `packetData` as mutable.
    ///
    /// - warning: Will error out if `packetData` is not an instance of `NSMutableData`.
    var mutablePacketData: NSMutableData! {
        // swiftlint:disable:next force_cast
        return packetData as! NSMutableData
    }

    /**
     Initailize a new instance to build IP packet.
     */
    init() {}

    /**
     Initailize an `IPPacket` with data.

     - parameter packetData: The data containing a whole packet.
     */
    init?(packetData: NSData) {
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

        guard packetData.length >= Int(headerLength) else {
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
        case .IPv4:
            sourceAddress = IPv4Address(fromUInt32InHostOrder: scanner.read32()!)
            destinationAddress = IPv4Address(fromUInt32InHostOrder: scanner.read32()!)
        default:
            // IPv6 is not supported yet.
            DDLogWarn("IPv6 is not supported yet.")
            return nil
        }

        switch transportProtocol! {
        case .UDP:
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
            result += address.UInt32InHostOrder >> 16 + address.UInt32InHostOrder & 0xFFFF
        }
        if let address = destinationAddress {
            result += address.UInt32InHostOrder >> 16 + address.UInt32InHostOrder & 0xFFFF
        }
        result += UInt32(transportProtocol.rawValue) << 8
        result += UInt32(protocolParser.bytesLength)
        return result
    }

    func buildPacket() {
        packetData = NSMutableData(length: Int(headerLength) + protocolParser.bytesLength)

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
        setPayloadWithUInt32(sourceAddress.inaddr, at: 12, swap: false)
        setPayloadWithUInt32(destinationAddress.inaddr, at: 16, swap: false)

        // let TCP or UDP packet build
        protocolParser.packetData = packetData
        protocolParser.offset = Int(headerLength)
        protocolParser.buildSegment(computePseudoHeaderChecksum())

        setPayloadWithUInt16(Checksum.computeChecksum(packetData, from: 0, to: Int(headerLength)), at: 10, swap: false)
    }

    func setPayloadWithUInt8(value: UInt8, at: Int) {
        var v = value
        mutablePacketData.replaceBytesInRange(NSRange(location: at, length: 1), withBytes: &v)
    }

    func setPayloadWithUInt16(value: UInt16, at: Int, swap: Bool = true) {
        var v: UInt16
        if swap {
            v = CFSwapInt16HostToBig(value)
        } else {
            v = value
        }
        mutablePacketData.replaceBytesInRange(NSRange(location: at, length: 2), withBytes: &v)
    }

    func setPayloadWithUInt32(value: UInt32, at: Int, swap: Bool = true) {
        var v: UInt32
        if swap {
            v = CFSwapInt32HostToBig(value)
        } else {
            v = value
        }
        mutablePacketData.replaceBytesInRange(NSRange(location: at, length: 4), withBytes: &v)
    }

    func setPayloadWithData(data: NSData, at: Int, length: Int? = nil, from: Int = 0) {
        var length = length
        if length == nil {
            length = data.length - from
        }
        let pointer = data.bytes.advancedBy(from)
        mutablePacketData.replaceBytesInRange(NSRange(location: at, length: length!), withBytes: pointer)
    }

    func resetPayloadAt(at: Int, length: Int) {
        mutablePacketData.resetBytesInRange(NSRange(location: at, length: length))
    }

}
