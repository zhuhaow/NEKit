import Foundation
import CocoaLumberjackSwift

class IPPacket {
    static func peekTransportType(data: NSData) -> TransportType? {
        guard data.length > 20 else {
            return nil
        }

        return TransportType(rawValue: UnsafePointer<UInt8>(data.bytes).advancedBy(9).memory)
    }

    static func peekDestinationAddress(data: NSData) -> IPv4Address? {
        guard data.length > 20 else {
            return nil
        }

        return IPv4Address(fromBytesInNetworkOrder: data.bytes.advancedBy(16))
    }

    static func peekDestinationPort(data: NSData) -> Port? {
        guard data.length > 20 else {
            return nil
        }

        // assume IP packet does have option
        return Port(bytesInNetworkOrder: data.bytes.advancedBy(22))
    }


    /// The version of the current IP packet.
    var version: IPVersion = .IPv4
    /// The length of the IP packet header.
    var headerLength: UInt8 = 20
    /// This contains the DSCP and ECN of the IP packet. Since we can not send custom IP packet out with NetworkExtension, this is useless and simply ignored.
    var tos: UInt8 = 0

    /// This should be the length of the datagram which should be the length of the payload.
    /// This value is not read from header since NEPacketTunnelFlow has already taken care of it for us.
    var totalLength: UInt16 {
        get {
            // payloadOffset should always be 0
            // this should always be equal to `20 + transportSegment.bytesLength`
            return UInt16(datagram.length - payloadOffset)
        }
    }

    /// Identification of the current packet. Since we do not support fragment, this is ignored and always will be zero. But you should set it whenever possible, e.g., when replying to DNS request, you can set this to be the same as the request packet.
    /// - note: Theoratically, this should be a sequentially increasing number. It probably will be implemented.
    var identification: UInt16 = 0
    /// Offset of the current packet. Since we do not support fragment, this is ignored and always will be zero.
    var offset: UInt16 = 0

    var TTL: UInt8 = 64

    var sourceAddress: IPv4Address!
    var destinationAddress: IPv4Address!
    var transportType: TransportType!
    var transportSegment: TransportProtocol!

    var datagram: NSData!
    var mutableDatagram: NSMutableData! {
        // swiftlint:disable:next force_cast
        return datagram as! NSMutableData
    }
    var payloadOffset: Int = 0

    init() {}

    init?(datagram: NSData) {
        // no need to validate the packet.

        self.datagram = datagram

        let scanner = BinaryDataScanner(data: datagram, littleEndian: false)
        scanner.skipTo(payloadOffset)

        let vhl = scanner.readByte()!
        guard let v = IPVersion(rawValue: vhl >> 4) else {
            DDLogError("Got unknown ip packet version \(vhl >> 4)")
            return nil
        }
        version = v
        headerLength = vhl & 0x0F * 4
        if headerLength != 20 {
            DDLogWarn("Received an IP packet with option, which is not supported yet. The option is ignored.")
        }

        tos = scanner.readByte()!

        guard totalLength == scanner.read16()! else {
            DDLogError("Packet length mismatches from header.")
            return nil
        }

        identification = scanner.read16()!
        offset = scanner.read16()!
        TTL = scanner.readByte()!

        guard let proto = TransportType(rawValue: scanner.readByte()!) else {
            DDLogWarn("Get unsupported packet protocol.")
            return nil
        }
        transportType = proto

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

        switch transportType! {
        case .UDP:
            guard let transportSegment = UDPSegment(rawSegment: datagram.subdataWithRange(NSRange(location: Int(headerLength), length: datagram.length - Int(headerLength)))) else {
            return nil
            }
            self.transportSegment = transportSegment
        default:
            DDLogError("Can not parse packet header of type \(transportType) yet")
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
        result += UInt32(transportType.rawValue) << 8
        result += UInt32(transportSegment.bytesLength)
        return result
    }

    func buildPacket() {
        datagram = NSMutableData(length: Int(headerLength) + transportSegment.bytesLength)

        // set header
        setPayloadWithUInt8(headerLength / 4 + version.rawValue << 4, at: 0)
        setPayloadWithUInt8(tos, at: 1)
        setPayloadWithUInt16(totalLength, at: 2)
        setPayloadWithUInt16(identification, at: 4)
        setPayloadWithUInt16(offset, at: 6)
        setPayloadWithUInt8(TTL, at: 8)
        setPayloadWithUInt8(transportType.rawValue, at: 9)
        // clear checksum bytes
        resetPayloadAt(10, length: 2)
        setPayloadWithUInt32(sourceAddress.inaddr, at: 12, swap: false)
        setPayloadWithUInt32(destinationAddress.inaddr, at: 16, swap: false)

        // let TCP or UDP packet build
        let transportData = transportSegment.buildSegment(computePseudoHeaderChecksum())
        setPayloadWithData(transportData, at: Int(headerLength))

        setPayloadWithUInt16(Checksum.computeChecksum(datagram, from: 0, to: Int(headerLength)), at: 10, swap: false)
    }

    func setPayloadWithUInt8(value: UInt8, at: Int) {
        var v = value
        mutableDatagram.replaceBytesInRange(NSRange(location: at + payloadOffset, length: 1), withBytes: &v)
    }

    func setPayloadWithUInt16(value: UInt16, at: Int, swap: Bool = true) {
        var v: UInt16
        if swap {
            v = CFSwapInt16HostToBig(value)
        } else {
            v = value
        }
        mutableDatagram.replaceBytesInRange(NSRange(location: at + payloadOffset, length: 2), withBytes: &v)
    }

    func setPayloadWithUInt32(value: UInt32, at: Int, swap: Bool = true) {
        var v: UInt32
        if swap {
            v = CFSwapInt32HostToBig(value)
        } else {
            v = value
        }
        mutableDatagram.replaceBytesInRange(NSRange(location: at + payloadOffset, length: 4), withBytes: &v)
    }

    func setPayloadWithData(data: NSData, at: Int, length: Int? = nil, from: Int = 0) {
        var length = length
        if length == nil {
            length = data.length - from
        }
        let pointer = data.bytes.advancedBy(from)
        mutableDatagram.replaceBytesInRange(NSRange(location: at, length: length!), withBytes: pointer)
    }

    func resetPayloadAt(at: Int, length: Int) {
        mutableDatagram.resetBytesInRange(NSRange(location: at, length: length))
    }

}

protocol TransportProtocol {
    var sourcePort: Port! { get set }
    var destinationPort: Port! { get set }

    var payload: NSData! { get set }

    var bytesLength: Int { get }

    func buildSegment(pseudoHeaderChecksum: UInt32) -> NSData
}

class UDPSegment: TransportProtocol {
    var sourcePort: Port!
    var destinationPort: Port!

    var payload: NSData!

    var bytesLength: Int {
        return payload.length + 8
    }

    init() {}

    init?(rawSegment: NSData) {
        guard rawSegment.length > 8 else {
            return nil
        }

        sourcePort = Port(bytesInNetworkOrder: rawSegment.bytes)
        destinationPort = Port(bytesInNetworkOrder: rawSegment.bytes.advancedBy(2))
        self.payload = rawSegment.subdataWithRange(NSRange(location: 8, length: rawSegment.length - 8))
    }

    func buildSegment(pseudoHeaderChecksum: UInt32) -> NSData {
        let datagram = NSMutableData(length: bytesLength)!
        datagram.replaceBytesInRange(NSRange(location: 0, length: 2), withBytes: sourcePort.bytesInNetworkOrder)
        datagram.replaceBytesInRange(NSRange(location: 2, length: 2), withBytes: destinationPort.bytesInNetworkOrder)
        var length = NSSwapHostShortToBig(UInt16(payload.length))
        datagram.replaceBytesInRange(NSRange(location: 4, length: 2), withBytes: &length)
        datagram.replaceBytesInRange(NSRange(location: 8, length: payload.length), withBytes: payload.bytes)
        datagram.resetBytesInRange(NSRange(location: 6, length: 2))
//        var checksum = Checksum.computeChecksum(datagram, from: 0, to: nil, withPseudoHeaderChecksum: pseudoHeaderChecksum)
//        datagram.replaceBytesInRange(NSRange(location: 6, length: 2), withBytes: &checksum)
        return datagram
    }
}
