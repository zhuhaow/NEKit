import Foundation

public class Port: CustomStringConvertible, Hashable {
    private var inport: UInt16

    init(portInNetworkOrder: UInt16) {
        self.inport = portInNetworkOrder
    }

    public convenience init(port: UInt16) {
        self.init(portInNetworkOrder: NSSwapHostShortToBig(port))
    }

    convenience init(bytesInNetworkOrder: UnsafePointer<Void>) {
        self.init(portInNetworkOrder: UnsafePointer<UInt16>(bytesInNetworkOrder).memory)
    }

    public var description: String {
        return "<Port \(value)>"
    }

    var value: UInt16 {
        return NSSwapBigShortToHost(inport)
    }

    var intValue: Int {
        return Int(value)
    }

    var valueInNetworkOrder: UInt16 {
        return inport
    }

    public var hashValue: Int {
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

public func == (left: Port, right: Port) -> Bool {
    return left.hashValue == right.hashValue
}
