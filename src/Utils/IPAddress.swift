import Foundation

public protocol IPAddress: CustomStringConvertible, Hashable {
    init?(fromString: String)
    init(fromBytesInNetworkOrder: [UInt8])
    init(fromBytesInNetworkOrder: UnsafeRawPointer)

    var dataInNetworkOrder: Data { get }
}

open class IPv4Address: IPAddress {
    fileprivate var _in_addr: in_addr

    public init(fromInAddr: in_addr) {
        _in_addr = fromInAddr
    }

    public init(fromUInt32InHostOrder: UInt32) {
        _in_addr = in_addr(s_addr: NSSwapHostIntToBig(fromUInt32InHostOrder))
    }

    required public init(fromBytesInNetworkOrder: UnsafeRawPointer) {
        _in_addr = fromBytesInNetworkOrder.load(as: in_addr.self)
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
        presentation = fromString
    }

    required public init(fromBytesInNetworkOrder: [UInt8]) {
        var inaddr: in_addr! = nil
        fromBytesInNetworkOrder.withUnsafeBufferPointer {
            inaddr = UnsafeRawPointer($0.baseAddress!).load(as: in_addr.self)
        }
        _in_addr = inaddr
    }

    lazy var presentation: String = { [unowned self] in
        var buffer = [Int8](repeating: 0, count: Int(INET_ADDRSTRLEN))
        var p: UnsafePointer<Int8>! = nil
        withUnsafePointer(to: &self._in_addr) { (ptr: UnsafePointer<in_addr>) in
            p = inet_ntop(AF_INET, ptr, &buffer, UInt32(INET_ADDRSTRLEN))
        }
        return String(cString: p)
    }()

    open var description: String {
        return "<IPv4Address \(presentation)>"
    }

    open var hashValue: Int {
        return _in_addr.s_addr.hashValue
    }

    open var UInt32InHostOrder: UInt32 {
        return NSSwapBigIntToHost(_in_addr.s_addr)
    }

    open var UInt32InNetworkOrder: UInt32 {
        return _in_addr.s_addr
    }

    open func withBytesInNetworkOrder(_ block: (UnsafeRawPointer) -> Void) {
        withUnsafePointer(to: &_in_addr) {
            block($0)
        }
    }

    open var dataInNetworkOrder: Data {
        return Data(bytes: &_in_addr, count: MemoryLayout.size(ofValue: _in_addr))
    }
}

public class IPv6Address: IPAddress {
    public var dataInNetworkOrder: Data {
        return Data(bytes: &_in6_addr, count: MemoryLayout.size(ofValue: _in6_addr))
    }

    public required init(fromBytesInNetworkOrder: UnsafeRawPointer) {
        _in6_addr = fromBytesInNetworkOrder.load(as: in6_addr.self)
    }

    public required init(fromBytesInNetworkOrder: [UInt8]) {
        var in6addr: in6_addr! = nil
        fromBytesInNetworkOrder.withUnsafeBytes {
            in6addr = $0.load(as: in6_addr.self)
        }
        _in6_addr = in6addr
    }

    fileprivate var _in6_addr: in6_addr

    public required init?(fromString: String) {
        var addr: in6_addr = in6_addr()
        var result: Int32 = 0
        fromString.withCString {
            result = inet_pton(AF_INET6, $0, &addr)
        }

        guard result == 1 else {
            return nil
        }
        _in6_addr = addr
        presentation = fromString
    }

    lazy var presentation: String = { [unowned self] in
        var buffer = [Int8](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        var p: UnsafePointer<Int8>! = nil
        withUnsafePointer(to: &self._in6_addr) { (ptr: UnsafePointer<in6_addr>) in
            p = inet_ntop(AF_INET6, ptr, &buffer, UInt32(INET6_ADDRSTRLEN))
        }
        return String(cString: p)
    }()

    open var description: String {
        return "<IPv6Address \(presentation)>"
    }

    open var hashValue: Int {
        return withUnsafeBytes(of: &_in6_addr.__u6_addr) {
            return $0.load(as: Int.self) ^ $0.load(fromByteOffset: MemoryLayout<Int>.size, as: Int.self)
        }
    }
}

public func == (left: IPv4Address, right: IPv4Address) -> Bool {
    return left.hashValue == right.hashValue
}

public func == (left: IPv6Address, right: IPv6Address) -> Bool {
    return left._in6_addr.__u6_addr.__u6_addr32 == right._in6_addr.__u6_addr.__u6_addr32
}

public func ==<T: IPAddress> (left: T, right: T) -> Bool {
    switch (left, right) {
    case let (l as IPv4Address, r as IPv4Address):
        return l == r
    case let (l as IPv6Address, r as IPv6Address):
        return l == r
    default:
        return false
    }
}
