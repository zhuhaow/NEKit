import Foundation

public enum IPRangeError: ErrorType {
    case InvalidCIDRFormat, InvalidRangeFormat, RangeIsTooLarge, InvalidFormat
}

public class IPRange {
    let baseIP: IPv4Address
    let range: UInt32

    init(baseIP: IPv4Address, range: UInt32) throws {
        guard baseIP.UInt32InHostOrder &+ range > range else {
            throw IPRangeError.RangeIsTooLarge
        }

        self.baseIP = baseIP
        self.range = range
    }

    convenience init(withCIDRString rep: String) throws {
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

        try self.init(baseIP: ip, range: UInt32.max >> mask)
    }

    convenience init(withRangeString rep: String) throws {
        let info = rep.componentsSeparatedByString("+")
        guard info.count == 2 else {
            throw IPRangeError.InvalidRangeFormat
        }

        guard let ip = IPv4Address(fromString: info[0]), range = UInt32(info[1]) else {
            throw IPRangeError.InvalidRangeFormat
        }

        try self.init(baseIP: ip, range: range)
    }

    convenience init(withString rep: String) throws {
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

    func inRange(ip: IPv4Address) -> Bool {
        return ip.UInt32InHostOrder >= baseIP.UInt32InHostOrder && ip.UInt32InHostOrder <= baseIP.UInt32InHostOrder + range
    }
}
