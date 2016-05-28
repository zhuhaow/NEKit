import Foundation

class Port: CustomStringConvertible, Hashable {
    private var inport: UInt16

    init(portInNetworkOrder: UInt16) {
        self.inport = portInNetworkOrder
    }

    convenience init(port: UInt16) {
        self.init(portInNetworkOrder: NSSwapHostShortToBig(port))
    }

    convenience init(bytesInNetworkOrder: UnsafePointer<Void>) {
        self.init(portInNetworkOrder: UnsafePointer<UInt16>(bytesInNetworkOrder).memory)
    }

    var description: String {
        return "Port: \(value)"
    }

    var value: UInt16 {
        return NSSwapBigShortToHost(inport)
    }

    var valueInNetworkOrder: UInt16 {
        return inport
    }

    var hashValue: Int {
        return Int(inport)
    }

    var bytesInNetworkOrder: UnsafePointer<Void> {
        var pointer: UnsafePointer<Void> = nil
        withUnsafePointer(&inport) {
            pointer = UnsafePointer<Void>($0)
        }
        return pointer
    }
}

func == (left: Port, right: Port) -> Bool {
    return left.hashValue == right.hashValue
}
