import Foundation

class IPRange {
    let baseIP: IPv4Address
    let range: UInt32

    init?(baseIP: IPv4Address, range: UInt32) {
        guard baseIP.UInt32InHostOrder &+ range > range else {
            return nil
        }

        self.baseIP = baseIP
        self.range = range
    }

    convenience init?(withCIDRString rep: String) {
        let info = rep.componentsSeparatedByString("/")
        guard info.count == 2 else {
            return nil
        }

        guard let ip = IPv4Address(fromString: info[0]), mask = UInt32(info[1]) else {
            return nil
        }

        guard mask <= 32 else {
            return nil
        }

        self.init(baseIP: ip, range: UInt32.max >> mask)
    }

    convenience init?(withRangeString rep: String) {
        let info = rep.componentsSeparatedByString("+")
        guard info.count == 2 else {
            return nil
        }

        guard let ip = IPv4Address(fromString: info[0]), range = UInt32(info[1]) else {
            return nil
        }

        self.init(baseIP: ip, range: range)
    }

    convenience init?(withString rep: String) {
        if rep.containsString("/") {
            self.init(withCIDRString: rep)
        } else if rep.containsString("+") {
            self.init(withRangeString: rep)
        } else {
            guard let ip = IPv4Address(fromString: rep) else {
                return nil
            }

            self.init(baseIP: ip, range: 0)
        }
    }

    func inRange(ip: IPv4Address) -> Bool {
        return ip.UInt32InHostOrder >= baseIP.UInt32InHostOrder && ip.UInt32InHostOrder <= baseIP.UInt32InHostOrder + range
    }
}
