import Foundation

enum IPVersion: Int {
    case IPv4 = 4, IPv6 = 6
}

enum IPProtocol: Int {
    case TCP = 6, UDP = 17
}

class IPAddress {

}

class IPv4Address: IPAddress {
    let inaddr: UInt32
    init(address: UInt32) {
        inaddr = address
    }
}

enum ChangeType {
    case Address, Port
}

public class IPPacket {
    let version: IPVersion
    let proto: IPProtocol
    let IPHeaderLength: Int
    var sourceAddress: IPv4Address {
        get {
            let u32 = UnsafePointer<UInt32>(payload.bytes.advancedBy(12)).memory
            return IPv4Address(address: NSSwapBigIntToHost(u32))
        }
        set {
            setIPv4Address(sourceAddress, newAddress: newValue, at: 12)
        }
    }
    var destinationAddress: IPv4Address {
        get {
            let u32 = UnsafePointer<UInt32>(payload.bytes.advancedBy(16)).memory
            return IPv4Address(address: NSSwapBigIntToHost(u32))
        }
        set {
            setIPv4Address(sourceAddress, newAddress: newValue, at: 16)
        }
    }

    let payload: NSMutableData

    public init(payload: NSData) {
        let vl = UnsafePointer<UInt8>(payload.bytes).memory
        version = IPVersion(rawValue: Int(vl >> 4))!
        IPHeaderLength = Int(vl & 0x0F) * 4
        let p = UnsafePointer<UInt8>(payload.bytes.advancedBy(9)).memory
        proto = IPProtocol(rawValue: Int(p))!
        self.payload = NSMutableData(data: payload)
    }

    func updateChecksum(oldValue: UInt16, newValue: UInt16, type: ChangeType) {
        if type == .Address {
            updateChecksum(oldValue, newValue: newValue, at: 10)
        }
    }

    internal func updateChecksum(oldValue: UInt16, newValue: UInt16, at: Int) {
        let oldChecksum = UnsafePointer<UInt16>(payload.bytes.advancedBy(10)).memory
        var newChecksum = ~(~oldChecksum + ~oldValue + newValue)
        payload.replaceBytesInRange(NSRange(location: at, length: 2), withBytes: &newChecksum, length: 2)
    }

    private func setIPv4Address(oldAddress: IPv4Address, newAddress: IPv4Address, at: Int) {
        var oaddr: UInt32 = NSSwapHostIntToBig(oldAddress.inaddr)
        let in_addr = newAddress.inaddr
        var naddr: UInt32 = NSSwapHostIntToBig(in_addr)
        payload.replaceBytesInRange(NSRange(location: at, length: 4), withBytes: &naddr, length: 4)
        withUnsafePointers(&oaddr, &naddr) { op, np in
            updateChecksum(UnsafePointer<UInt16>(op).memory, newValue: UnsafePointer<UInt16>(np).memory, type: .Address)
            updateChecksum(UnsafePointer<UInt16>(op).advancedBy(1).memory, newValue: UnsafePointer<UInt16>(np).advancedBy(1).memory, type: .Address)
        }
    }
}
