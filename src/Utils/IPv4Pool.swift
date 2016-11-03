import Foundation
import CocoaLumberjackSwift

/**
 The pool is build to hold fake ips.
 It is built under the strong assumtion that the start and end ips will end with 0, e.g, X.X.X.0, and stepSize will only be 256.

 - note: It is NOT thread-safe.
 */
public final class IPv4Pool {
    let start: UInt32
    let end: UInt32
    var currentEnd: UInt32
    let stepSize: UInt32 = 256
    var pool: [UInt32] = []

    public init(start: IPv4Address, end: IPv4Address) {
        self.start = start.UInt32InHostOrder
        self.end = end.UInt32InHostOrder
        self.currentEnd = self.start
    }

    fileprivate func enlargePool() -> Bool {
        guard end > currentEnd else {
            DDLogError("The Fake IP Pool is full and cannot be enlarged. Try to enlarge the size of fake ip pool in configuration.")
            return false
        }

        pool.reserveCapacity(pool.count + Int(stepSize))

        // only use ip from .1 to .254
        for i in 1..<stepSize - 1 {
            pool.append(currentEnd + i)
        }

        currentEnd += stepSize
        return true
    }

    func fetchIP() -> IPv4Address? {
        if pool.count == 0 {
            guard enlargePool() else {
                return nil
            }
        }

        return IPv4Address(fromUInt32InHostOrder: pool.removeFirst())
    }

    func releaseIP(_ ipAddress: IPv4Address) {
        pool.append(ipAddress.UInt32InHostOrder)
    }

    func isInPool(_ ipAddress: IPv4Address) -> Bool {
        let addr = ipAddress.UInt32InHostOrder
        return addr >= start && addr < end
    }
}
