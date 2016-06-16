import Foundation

class TCPMutablePacket: IPMutablePacket {
    var sourcePort: Port {
        get {
            return Port(bytesInNetworkOrder: payload.bytes.advancedBy(IPHeaderLength))
        }
        set {
            setPort(sourcePort, newPort: newValue, at: 0)
        }
    }

    var destinationPort: Port {
        get {
            return Port(bytesInNetworkOrder: payload.bytes.advancedBy(IPHeaderLength + 2))
        }
        set {
            setPort(destinationPort, newPort: newValue, at: 2)
        }
    }

    override func updateChecksum(oldValue: UInt16, newValue: UInt16, type: ChangeType) {
        super.updateChecksum(oldValue, newValue: newValue, type: type)
        updateChecksum(oldValue, newValue: newValue, at: IPHeaderLength + 16)
    }

    // swiftlint:disable:next variable_name
    private func setPort(oldPort: Port, newPort: Port, at: Int) {
        payload.replaceBytesInRange(NSRange(location: at + IPHeaderLength, length: 2), withBytes: newPort.bytesInNetworkOrder, length: 2)
        updateChecksum(oldPort.valueInNetworkOrder, newValue: newPort.valueInNetworkOrder, type: .Port)
    }
}
