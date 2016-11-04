import Foundation

public protocol IPAddress: CustomStringConvertible {
    init?(fromString: String)
    init(fromBytesInNetworkOrder: [UInt8])
    init(fromBytesInNetworkOrder: UnsafeRawPointer)

    var dataInNetworkOrder: Data { get }
}

open class IPv4Address: IPAddress, Hashable {
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

    open func withBytesInNetworkOrder(_ block: (UnsafeRawPointer) -> ()) {
        withUnsafePointer(to: &_in_addr) {
            block($0)
        }
    }

    open var dataInNetworkOrder: Data {
        return Data(bytes: &_in_addr, count: MemoryLayout.size(ofValue: _in_addr))
    }
}

public func == (left: IPv4Address, right: IPv4Address) -> Bool {
    return left.hashValue == right.hashValue
}
