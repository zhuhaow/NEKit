import Foundation

/// Represents the port number of IP protocol.
@objc public class Port: NSObject, ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = UInt16

    fileprivate var inport: UInt16

    /**
     Initialize a new instance with the port number in network byte order.

     - parameter portInNetworkOrder: The port number in network byte order.

     - returns: The initailized port.
     */
    public init(portInNetworkOrder: UInt16) {
        self.inport = portInNetworkOrder
        super.init()
    }

    /**
     Initialize a new instance with the port number.

     - parameter port: The port number.

     - returns: The initailized port.
     */
    public convenience init(port: UInt16) {
        self.init(portInNetworkOrder: NSSwapHostShortToBig(port))
    }

    public required convenience init(integerLiteral value: Port.IntegerLiteralType) {
        self.init(port: value)
    }

    /**
     Initialize a new instance with data in network byte order.

     - parameter bytesInNetworkOrder: The port data in network byte order.

     - returns: The initailized port.
     */
    public convenience init(bytesInNetworkOrder: UnsafeRawPointer) {
        self.init(portInNetworkOrder: bytesInNetworkOrder.load(as: UInt16.self))
    }

    public override var description: String {
        return "<Port \(value)>"
    }

    /// The port number.
    public var value: UInt16 {
        return NSSwapBigShortToHost(inport)
    }

    public var valueInNetworkOrder: UInt16 {
        return inport
    }

    /// The hash value of the port.
    public override var hashValue: Int {
        return Int(inport)
    }

    /**
     Run a block with the bytes of port in **network order**.

     - parameter block: The block to run.

     - returns: The value the block returns.
     */
    public func withUnsafeBufferPointer<T>(_ block: (UnsafeRawBufferPointer) -> T) -> T {
        return withUnsafeBytes(of: &inport) {
            return block($0)
        }
    }
}

public func == (left: Port, right: Port) -> Bool {
    return left.valueInNetworkOrder == right.valueInNetworkOrder
}
