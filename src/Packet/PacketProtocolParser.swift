import Foundation

protocol TransportProtocolParserProtocol {
    var packetData: NSData! { get set }

    var offset: Int { get set }

    var bytesLength: Int { get }

    var payload: NSData! { get set }

    func buildSegment(pseudoHeaderChecksum: UInt32)
}

/// Parser to process UDP packet and build packet.
class UDPProtocolParser: TransportProtocolParserProtocol {
    /// The source port.
    var sourcePort: Port!

    /// The destination port.
    var destinationPort: Port!

    /// The data containing the UDP segment.
    var packetData: NSData!

    /// The mutable version of the data containing the UDP segment.
    var mutablePacketData: NSMutableData {
        // swiftlint:disable:next force_cast
        return packetData as! NSMutableData
    }

    /// The offset of the UDP segment in the `packetData`.
    var offset: Int = 0

    /// The payload to be encapsulated.
    var payload: NSData!

    /// The length of the UDP segment.
    var bytesLength: Int {
        return payload.length + 8
    }

    init() {}

    init?(packetData: NSData, offset: Int) {
        guard packetData.length >= offset + 8 else {
            return nil
        }

        self.packetData = packetData
        self.offset = offset

        sourcePort = Port(bytesInNetworkOrder: packetData.bytes.advancedBy(offset))
        destinationPort = Port(bytesInNetworkOrder: packetData.bytes.advancedBy(offset + 2))

        payload = packetData.subdataWithRange(NSRange(location: 8, length: payload.length - offset - 8))
    }

    func buildSegment(pseudoHeaderChecksum: UInt32) {
        mutablePacketData.replaceBytesInRange(NSRange(location: offset, length: 2), withBytes: sourcePort.bytesInNetworkOrder)
        mutablePacketData.replaceBytesInRange(NSRange(location: 2 + offset, length: 2), withBytes: destinationPort.bytesInNetworkOrder)
        var length = NSSwapHostShortToBig(UInt16(bytesLength))
        mutablePacketData.replaceBytesInRange(NSRange(location: 4 + offset, length: 2), withBytes: &length)
        mutablePacketData.replaceBytesInRange(NSRange(location: 8 + offset, length: payload.length), withBytes: payload.bytes)
        mutablePacketData.resetBytesInRange(NSRange(location: 6 + offset, length: 2))

        // Todo: compute checksum
//        var checksum = Checksum.computeChecksum(datagram, from: 0, to: nil, withPseudoHeaderChecksum: pseudoHeaderChecksum)
//        datagram.replaceBytesInRange(NSRange(location: 6, length: 2), withBytes: &checksum)
    }
}
