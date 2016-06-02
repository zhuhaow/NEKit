import Foundation
import NetworkExtension
import CocoaLumberjackSwift

class DNSServer: NWUDPSocketDelegate {
    let timer: dispatch_source_t
    let queue: dispatch_queue_t = dispatch_queue_create("NEKit.DNSServer", DISPATCH_QUEUE_SERIAL)
    var fakeSessions: [IPv4Address: DNSSession] = [:]
    var pendingSessions: [UInt16: DNSSession] = [:]
    let pool: IPv4Pool
    var DNSServers: [NWUDPSocket] = []

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

    private func lookup(message: DNSMessage) {
        guard let session = DNSSession(message: message) else {
            // ignore everything not a query
            return
        }

        RuleManager.currentManager.matchDNS(session, type: .Domain)

        switch session.matchResult! {
        case .Fake:
            setUpFakeIP(session)
            outputSession(session)
        case .Real, .Unknown:
            lookupRemotely(session)
        default:
            DDLogError("The rule match result should never be .Pass.")
        }
    }

    private func lookupRemotely(session: DNSSession) {
        pendingSessions[session.requestMessage.transactionID] = session
        sendQueryToRemote(session)
    }

    private func sendQueryToRemote(session: DNSSession) {
        for server in DNSServers {
            server.writeData(session.requestMessage.payload)
        }
    }

    func inputMessage(data: NSData) {
        let message = DNSMessage(payload: data)
        lookup(message)
    }

    func outputSession(session: DNSSession) {}

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

    func getCurrentDNSServers() {
        let servers = LibresolvWrapper.fetchDNSServers()

        guard servers.count > 0 else {
            DDLogError("Failed to get current DNS server settings.")
            return
        }

        for server in servers {
            let socket = NWUDPSocket(host: server, port: 53)
            socket.delegate = self
            socket.queue = queue
            DNSServers.append(socket)
        }
    }

    func didReceiveData(data: NSData, from: NWUDPSocket) {
        // TODO: The parsing of DNSMessage should be guarded.
        let message = DNSMessage(payload: data)
        guard let session = pendingSessions.removeValueForKey(message.transactionID) else {
            // this should not be a problem if there are multiple DNS servers or the DNS server is hijacked.
            DDLogVerbose("Do not find the corresponding DNS session for the response.")
            return
        }

        session.realResponseMessage = message
        // TODO: this should be guarded.
        // TODO: check return code.
        session.realIP = message.answers[0].ipv4Address!

        RuleManager.currentManager.matchDNS(session, type: .IP)

        switch session.matchResult! {
        case .Fake:
            setUpFakeIP(session)
            outputSession(session)
        case .Real:
            outputSession(session)
        default:
            DDLogError("The rule match result should never be .Pass or .Unknown in IP mode.")
        }
    }
}

/**
 The pool is build to hold fake ips.
 It is built under the strong assumtion that the start and end ips will end with 0, e.g, X.X.X.0, and stepSize will only be 256.
 - note: It is NOT thread-safe.
*/
final class IPv4Pool {
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
