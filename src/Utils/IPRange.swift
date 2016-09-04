import Foundation

public enum IPRangeError: ErrorType {
    case InvalidCIDRFormat, InvalidRangeFormat, RangeIsTooLarge, InvalidFormat
}

public class IPRange {
    public let baseIP: IPv4Address
    public let range: UInt32

    public init(baseIP: IPv4Address, range: UInt32) throws {
        guard baseIP.UInt32InHostOrder &+ range >= baseIP.UInt32InHostOrder else {
            throw IPRangeError.RangeIsTooLarge
        }

        self.baseIP = baseIP
        self.range = range
    }

    public convenience init(withCIDRString rep: String) throws {
        let info = rep.componentsSeparatedByString("/")
        guard info.count == 2 else {
            throw IPRangeError.InvalidCIDRFormat
        }

        guard let ip = IPv4Address(fromString: info[0]), mask = UInt32(info[1]) else {
            throw IPRangeError.InvalidCIDRFormat
        }

        guard mask <= 32 else {
            throw IPRangeError.InvalidCIDRFormat
        }

        try self.init(baseIP: ip, range: (1 << (32 - mask)) - 1 )
    }

    public convenience init(withRangeString rep: String) throws {
        let info = rep.componentsSeparatedByString("+")
        guard info.count == 2 else {
            throw IPRangeError.InvalidRangeFormat
        }

        guard let ip = IPv4Address(fromString: info[0]), range = UInt32(info[1]) else {
            throw IPRangeError.InvalidRangeFormat
        }

        try self.init(baseIP: ip, range: range)
    }

    public convenience init(withString rep: String) throws {
        if rep.containsString("/") {
            try self.init(withCIDRString: rep)
        } else if rep.containsString("+") {
            try self.init(withRangeString: rep)
        } else {
            guard let ip = IPv4Address(fromString: rep) else {
                throw IPRangeError.InvalidFormat
            }

            try self.init(baseIP: ip, range: 0)
        }
    }

    public func inRange(ip: IPv4Address) -> Bool {
        return ip.UInt32InHostOrder >= baseIP.UInt32InHostOrder && ip.UInt32InHostOrder <= baseIP.UInt32InHostOrder + range
    }
}
