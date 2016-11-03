import Foundation

public enum IPRangeError: Error {
    case invalidCIDRFormat, invalidRangeFormat, rangeIsTooLarge, invalidFormat
}

open class IPRange {
    open let baseIP: IPv4Address
    open let range: UInt32

    public init(baseIP: IPv4Address, range: UInt32) throws {
        guard baseIP.UInt32InHostOrder &+ range >= baseIP.UInt32InHostOrder else {
            throw IPRangeError.rangeIsTooLarge
        }

        self.baseIP = baseIP
        self.range = range
    }

    public convenience init(withCIDRString rep: String) throws {
        let info = rep.components(separatedBy: "/")
        guard info.count == 2 else {
            throw IPRangeError.invalidCIDRFormat
        }

        guard let ip = IPv4Address(fromString: info[0]), let mask = UInt32(info[1]) else {
            throw IPRangeError.invalidCIDRFormat
        }

        guard mask <= 32 else {
            throw IPRangeError.invalidCIDRFormat
        }

        try self.init(baseIP: ip, range: (1 << (32 - mask)) - 1 )
    }

    public convenience init(withRangeString rep: String) throws {
        let info = rep.components(separatedBy: "+")
        guard info.count == 2 else {
            throw IPRangeError.invalidRangeFormat
        }

        guard let ip = IPv4Address(fromString: info[0]), let range = UInt32(info[1]) else {
            throw IPRangeError.invalidRangeFormat
        }

        try self.init(baseIP: ip, range: range)
    }

    public convenience init(withString rep: String) throws {
        if rep.contains("/") {
            try self.init(withCIDRString: rep)
        } else if rep.contains("+") {
            try self.init(withRangeString: rep)
        } else {
            guard let ip = IPv4Address(fromString: rep) else {
                throw IPRangeError.invalidFormat
            }

            try self.init(baseIP: ip, range: 0)
        }
    }

    open func inRange(_ ip: IPv4Address) -> Bool {
        return ip.UInt32InHostOrder >= baseIP.UInt32InHostOrder && ip.UInt32InHostOrder <= baseIP.UInt32InHostOrder + range
    }
}
