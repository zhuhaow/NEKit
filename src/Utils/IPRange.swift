import Foundation

public enum IPRangeError: Error {
    case invalidCIDRFormat, invalidRangeFormat, invalidRange, invalidFormat, addressIncompatible, noRange, intervalInvalid, invalidMask
}

public class IPRange {
    public let startIP: IPAddress
    // including, so we can include 255.255.255.255 in range.
    public let endIP: IPAddress

    public let family: IPAddress.Family

    public init(startIP: IPAddress, endIP: IPAddress) throws {
        guard startIP.family == endIP.family else {
            throw IPRangeError.addressIncompatible
        }

        guard startIP <= endIP else {
            throw IPRangeError.invalidRange
        }

        self.startIP = startIP
        self.endIP = endIP
        family = startIP.family
    }

    public convenience init(startIP: IPAddress, interval: IPInterval) throws {
        guard let endIP = startIP.advanced(by: interval) else {
            throw IPRangeError.intervalInvalid
        }

        try self.init(startIP: startIP, endIP: endIP)
    }

    public convenience init(startIP: IPAddress, mask: IPMask) throws {
        guard let (startIP, endIP) = mask.mask(baseIP: startIP) else {
            throw IPRangeError.invalidMask
        }

        try self.init(startIP: startIP, endIP: endIP)
    }

    public func contains(ip: IPAddress) -> Bool {
        guard ip.family == family else {
            return false
        }

        return ip >= startIP && ip <= endIP
    }
}

extension IPRange {
    public convenience init(withCIDRString rep: String) throws {
        let info = rep.components(separatedBy: "/")
        guard info.count == 2 else {
            throw IPRangeError.invalidCIDRFormat
        }

        guard let ip = IPAddress(fromString: info[0]) else {
            throw IPRangeError.invalidCIDRFormat
        }

        var mask: IPMask
        switch ip.family {
        case .IPv4:
            guard let m = UInt32(info[1]) else {
                throw IPRangeError.invalidCIDRFormat
            }
            mask = IPMask.IPv4(m)
        case .IPv6:
            guard let m6 = try? UInt128(info[1]) else {
                throw IPRangeError.invalidCIDRFormat
            }
            mask = IPMask.IPv6(m6)
        }

        try self.init(startIP: ip, mask: mask)
    }

    public convenience init(withRangeString rep: String) throws {
        let info = rep.components(separatedBy: "+")
        guard info.count == 2 else {
            throw IPRangeError.invalidRangeFormat
        }

        guard let startIP = IPAddress(fromString: info[0]) else {
            throw IPRangeError.invalidRangeFormat
        }

        var interval: IPInterval
        switch startIP.family {
        case .IPv4:
            guard let m = UInt32(info[1]) else {
                throw IPRangeError.invalidRangeFormat
            }
            interval = IPInterval.IPv4(m)
        case .IPv6:
            guard let m6 = try? UInt128(info[1]) else {
                throw IPRangeError.invalidRangeFormat
            }
            interval = IPInterval.IPv6(m6)
        }

        try self.init(startIP: startIP, interval: interval)
    }

    public convenience init(withString rep: String) throws {
        if rep.contains("/") {
            try self.init(withCIDRString: rep)
        } else if rep.contains("+") {
            try self.init(withRangeString: rep)
        } else {
            guard let ip = IPAddress(fromString: rep) else {
                throw IPRangeError.invalidFormat
            }

            try self.init(startIP: ip, endIP: ip)
        }
    }

}
