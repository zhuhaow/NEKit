import Foundation

class TCPPacket: IPPacket {
    var sourcePort: UInt16 {
        get {
            let sp = UnsafePointer<UInt16>(payload.bytes.advancedBy(IPHeaderLength)).memory
            return NSSwapBigShortToHost(sp)
        }
        set {
            setPort(sourcePort, newPort: newValue, at: 0)
        }
    }

    var destinationPort: UInt16 {
        get {
            let dp = UnsafePointer<UInt16>(payload.bytes.advancedBy(IPHeaderLength + 2)).memory
            return NSSwapBigShortToHost(dp)
        }
        set {
            setPort(destinationPort, newPort: newValue, at: 2)
        }
    }

    override func updateChecksum(oldValue: UInt16, newValue: UInt16, type: ChangeType) {
        super.updateChecksum(oldValue, newValue: newValue, type: type)
        updateChecksum(oldValue, newValue: newValue, at: 28)
    }

    private func setPort(oldPort: UInt16, newPort: UInt16, at: Int) {
        var oport: UInt16 = NSSwapHostShortToBig(oldPort)
        var nport: UInt16 = NSSwapHostShortToBig(newPort)
        payload.replaceBytesInRange(NSRange(location: at, length: 2), withBytes: &nport, length: 2)
        withUnsafePointers(&oport, &nport) { op, np in
            updateChecksum(UnsafePointer<UInt16>(op).memory, newValue: UnsafePointer<UInt16>(np).memory, type: .Port)
        }
    }
}
