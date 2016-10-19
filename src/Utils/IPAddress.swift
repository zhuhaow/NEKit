import Foundation

public protocol IPAddress: CustomStringConvertible {
    init?(fromString: String)
    init(fromBytesInNetworkOrder: [UInt8])
    init(fromBytesInNetworkOrder: UnsafePointer<Void>)

    var dataInNetworkOrder: NSData { get }
}

public class IPv4Address: IPAddress, Hashable {
    private var _in_addr: in_addr

    public init(fromInAddr: in_addr) {
        _in_addr = fromInAddr
    }

    public init(fromUInt32InHostOrder: UInt32) {
        _in_addr = in_addr(s_addr: NSSwapHostIntToBig(fromUInt32InHostOrder))
    }

    required public init(fromBytesInNetworkOrder: UnsafePointer<Void>) {
        _in_addr = UnsafePointer<in_addr>(fromBytesInNetworkOrder).memory
    }

    required public init?(fromString: String) {
        var addr: in_addr = in_addr()
        var result: Int32 = 0
        fromString.withCString {
            result = inet_pton(AF_INET, $0, &addr)
        }

        guard result == 1 else {
            return nil
        }
        _in_addr = addr
    }

    required public init(fromBytesInNetworkOrder: [UInt8]) {
        var inaddr: in_addr! = nil
        fromBytesInNetworkOrder.withUnsafeBufferPointer {
            inaddr = UnsafePointer<in_addr>($0.baseAddress).memory
        }
        _in_addr = inaddr
    }

    var presentation: String {
        var buffer = [Int8](count: Int(INET_ADDRSTRLEN), repeatedValue: 0)
        var addr = _in_addr
        let p = inet_ntop(AF_INET, &addr, &buffer, UInt32(INET_ADDRSTRLEN))
        return String.fromCString(p)!
    }

    public var description: String {
        return "<IPv4Address \(presentation)>"
    }

    public var hashValue: Int {
        return _in_addr.s_addr.hashValue
    }

    public var UInt32InHostOrder: UInt32 {
        return NSSwapBigIntToHost(_in_addr.s_addr)
    }

    public var UInt32InNetworkOrder: UInt32 {
        return _in_addr.s_addr
    }

    public func withBytesInNetworkOrder(block: (UnsafePointer<Void>) -> ()) {
        withUnsafePointer(&_in_addr) {
            block($0)
        }
    }

    public var dataInNetworkOrder: NSData {
        var data: NSData! = nil
        withBytesInNetworkOrder {
            data = NSData(bytes: $0, length: sizeofValue(self._in_addr))
        }
        return data
    }
}

public func == (left: IPv4Address, right: IPv4Address) -> Bool {
    return left.hashValue == right.hashValue
}
