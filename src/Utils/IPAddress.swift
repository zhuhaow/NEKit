import Foundation

public class IPAddress: CustomStringConvertible, Comparable {
    public enum Family {
        case IPv4, IPv6
    }

    public enum Address: Equatable {
        case IPv4(in_addr), IPv6(in6_addr)

        public var asUInt128: UInt128 {
            switch self {
            case .IPv4(let addr):
                return UInt128(addr.s_addr.byteSwapped)
            case .IPv6(var addr):
                var upperBits: UInt64 = 0, lowerBits: UInt64 = 0
                withUnsafeBytes(of: &addr) {
                    upperBits = $0.load(as: UInt64.self).byteSwapped
                    lowerBits = $0.load(fromByteOffset: MemoryLayout<UInt64>.size, as: UInt64.self).byteSwapped
                }
                return UInt128(upperBits: upperBits, lowerBits: lowerBits)
            }
        }
    }

    public let family: Family
    public let address: Address

    public lazy var presentation: String = { [unowned self] in
        switch self.address {
        case .IPv4(var addr):
            var buffer = [Int8](repeating: 0, count: Int(INET_ADDRSTRLEN))
            var p: UnsafePointer<Int8>! = nil
            withUnsafePointer(to: &addr) {
                p = inet_ntop(AF_INET, $0, &buffer, UInt32(INET_ADDRSTRLEN))
            }
            return String(cString: p)
        case .IPv6(var addr):
            var buffer = [Int8](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            var p: UnsafePointer<Int8>! = nil
            withUnsafePointer(to: &addr) {
                p = inet_ntop(AF_INET6, $0, &buffer, UInt32(INET6_ADDRSTRLEN))
            }
            return String(cString: p)
        }
    }()

    public init(fromInAddr addr: in_addr) {
        family = .IPv4
        address = .IPv4(addr)
    }

    public init(fromIn6Addr addr6: in6_addr) {
        family = .IPv6
        address = .IPv6(addr6)
    }

    public convenience init?(fromString string: String) {
        var addr = in_addr()

        if (string.withCString {
            return inet_pton(AF_INET, $0, &addr)
        }) == 1 {
            self.init(fromInAddr: addr)
            presentation = string
        } else {
            var addr6 = in6_addr()
            if (string.withCString {
                return inet_pton(AF_INET6, $0, &addr6)
            }) == 1 {
                self.init(fromIn6Addr: addr6)
                presentation = string
            } else {
                return nil
            }
        }
    }

    public convenience init(ipv4InNetworkOrder: UInt32) {
        let addr = in_addr(s_addr: ipv4InNetworkOrder)
        self.init(fromInAddr: addr)
    }

    public convenience init(ipv6InNetworkOrder: UInt128) {
        var ip = ipv6InNetworkOrder
        var addr = in6_addr()
        withUnsafeBytes(of: &ip) { ipptr in
            withUnsafeMutableBytes(of: &addr) { addrptr in
                addrptr.storeBytes(of: ipptr.load(fromByteOffset: MemoryLayout<UInt64>.size, as: UInt64.self), toByteOffset: 0, as: UInt64.self)
                addrptr.storeBytes(of: ipptr.load(as: UInt64.self), toByteOffset: MemoryLayout<UInt64>.size, as: UInt64.self)
            }
        }
        self.init(fromIn6Addr: addr)
    }

    public convenience init(fromBytesInNetworkOrder ptr: UnsafeRawPointer, family: Family = .IPv4) {
        switch family {
        case .IPv4:
            let addr = ptr.assumingMemoryBound(to: in_addr.self).pointee
            self.init(fromInAddr: addr)
        case .IPv6:
            let addr6 = ptr.assumingMemoryBound(to: in6_addr.self).pointee
            self.init(fromIn6Addr: addr6)
        }
    }

    public var description: String {
        return presentation
    }

    public var dataInNetworkOrder: Data {
        var outputData: Data? = nil
        withBytesInNetworkOrder {
            outputData = Data($0)
        }
        return outputData!
    }

    public var UInt32InNetworkOrder: UInt32? {
        switch self.address {
        case .IPv4(let addr):
            return addr.s_addr
        default:
            return nil
        }
    }

    public var UInt128InNetworkOrder: UInt128? {
        return self.address.asUInt128.byteSwapped
    }

    public func withBytesInNetworkOrder<U>(_ body: (UnsafeRawBufferPointer) throws -> U) rethrows -> U {
        switch address {
        case .IPv4(var addr):
            return try withUnsafeBytes(of: &addr, body)
        case .IPv6(var addr):
            return try withUnsafeBytes(of: &addr, body)
        }
    }

    public func advanced(by interval: IPInterval) -> IPAddress? {
        switch (interval, address) {
        case (.IPv4(let range), .IPv4(let addr)):
            return IPAddress(ipv4InNetworkOrder: (addr.s_addr.byteSwapped &+ range).byteSwapped)
        case (.IPv6(let range), .IPv6):
            return IPAddress(ipv6InNetworkOrder: (address.asUInt128 &+ range).byteSwapped)
        default:
            return nil
        }
    }

    public func advanced(by interval: UInt) -> IPAddress? {
        switch self.address {
        case .IPv4(let addr):
            return IPAddress(ipv4InNetworkOrder: (addr.s_addr.byteSwapped &+ UInt32(interval)).byteSwapped)
        case .IPv6:
            return IPAddress(ipv6InNetworkOrder: (address.asUInt128 &+ UInt128(interval)).byteSwapped)
        }
    }
}

public func == (lhs: IPAddress, rhs: IPAddress) -> Bool {
    return lhs.address == rhs.address
}

// Comparing IP addresses of different families are undefined.
// But currently, IPv4 is considered smaller than IPv6 address. Do NOT depend on this behavior.
public func < (lhs: IPAddress, rhs: IPAddress) -> Bool {
    switch (lhs.address, rhs.address) {
    case (.IPv4(let addrl), .IPv4(let addrr)):
        return addrl.s_addr.byteSwapped < addrr.s_addr.byteSwapped
    case (.IPv6(var addrl), .IPv6(var addrr)):
        let ms = MemoryLayout.size(ofValue: addrl)
        return (withUnsafeBytes(of: &addrl) { ptrl in
            withUnsafeBytes(of: &addrr) { ptrr in
                return memcmp(ptrl.baseAddress!, ptrr.baseAddress!, ms)
            }
        }) < 0
    case (.IPv4, .IPv6):
        return true
    case (.IPv6, .IPv4):
        return false
    }
}

public func == (lhs: IPAddress.Address, rhs: IPAddress.Address) -> Bool {
    switch (lhs, rhs) {
    case (.IPv4(let addrl), .IPv4(let addrr)):
        return addrl.s_addr == addrr.s_addr
    case (.IPv6(let addrl), .IPv6(let addrr)):
        return addrl.__u6_addr.__u6_addr32 == addrr.__u6_addr.__u6_addr32
    default:
        return false
    }
}

extension IPAddress: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch address {
        case .IPv4(let addr):
            return hasher.combine(addr.s_addr.hashValue)
        case .IPv6(var addr):
            return withUnsafeBytes(of: &addr) {
                return hasher.combine(bytes: $0)
            }
        }
    }
}
