import Foundation
import CocoaLumberjackSwift

class DNSServer {
    let timer: dispatch_source_t
    let queue: dispatch_queue_t = dispatch_queue_create("NEKit.DNSServer", DISPATCH_QUEUE_SERIAL)
    var fakeSessions: [IPv4Address: DNSSession] = [:]
    let pool: IPv4Pool

    init(fakeIPPool: IPv4Pool) {
        pool = fakeIPPool
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)

        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, NSEC_PER_SEC, NSEC_PER_SEC)

        dispatch_source_set_event_handler(timer) {
            [weak self] in
            self?.tmr()
        }
    }

    func tmr() {
        checkTimeoutRecords()
    }

    private func checkTimeoutRecords() {
        let now = NSDate()
        for (key, value) in fakeSessions {
            if value.expireAt != nil && value.expireAt!.compare(now) == .OrderedAscending {
                fakeSessions.removeValueForKey(key)
                pool.releaseIP(key)
            }
        }
    }

    private func lookup(message: DNSMessage, completeHandler: (DNSSession) -> ()) {
        guard let session = DNSSession(message: message) else {
            // ignore everything not a query
            return
        }

        switch RuleManager.currentManager.matchDNS(session, type: .Domain) {
        case .Fake:
            setUpFakeIP(session)
        case .Real:
        case .Unknown:
        default:
            DDLogError("The rule match result should never be .Pass.")
        }
    }

    private func lookupRemotely(session: DNSSession, completeHandler: (DNSSession) -> ()) {

    }

    func inputPacket(data: NSData) {
        let message = DNSMessage(payload: data)
        lookup(message, completeHandler: <#T##(DNSSession) -> ()#>)
    }

    func isFakeIP(ipAddress: IPv4Address) -> Bool {
        return pool.isInPool(ipAddress)
    }

    func setUpFakeIP(session: DNSSession) -> Bool {
        guard let fakeIP = pool.fetchIP() else {
            DDLogError("Failed to get a fake IP.")
            return false
        }
        session.fakeIP = fakeIP
        fakeSessions[fakeIP] = session
        return true
    }
}

/// The pool is build to hold fake ips.
/// It is built under the strong assumtion that the start and end ips will end with 0, e.g, X.X.X.0 and stepSize will only be 256.
/// It is NOT thread-safe.
class IPv4Pool {
    let start: UInt32
    let end: UInt32
    var currentEnd: UInt32
    let stepSize: UInt32 = 256
    var pool: [UInt32] = []

    init(start: IPv4Address, end: IPv4Address) {
        self.start = start.UInt32InHostOrder
        self.end = end.UInt32InHostOrder
        self.currentEnd = self.start
    }

    private func enlargePool() -> Bool {
        guard end - currentEnd > 0 else {
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

        return IPv4Address(fromUInt32InHostOrder: pool.first!)
    }

    func releaseIP(ipAddress: IPv4Address) {
        pool.append(ipAddress.UInt32InHostOrder)
    }

    func isInPool(ipAddress: IPv4Address) -> Bool {
        let addr = ipAddress.UInt32InHostOrder
        return addr >= start && addr < end
    }
}
