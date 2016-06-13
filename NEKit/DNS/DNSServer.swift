import Foundation
import NetworkExtension
import CocoaLumberjackSwift

public class DNSServer: NWUDPSocketDelegate, IPStackProtocol {
    static var currentServer: DNSServer?

    let serverAddress: IPv4Address
    let serverPort: Port
    let timer: dispatch_source_t
    let queue: dispatch_queue_t = dispatch_queue_create("NEKit.DNSServer", DISPATCH_QUEUE_SERIAL)
    var fakeSessions: [IPv4Address: DNSSession] = [:]
    var pendingSessions: [UInt16: DNSSession] = [:]
    let pool: IPv4Pool
    var DNSServers: [NWUDPSocket] = []
    public var outputFunc: (([NSData], [NSNumber]) -> ())!

    public init(address: IPv4Address, port: Port, fakeIPPool: IPv4Pool) {
        serverAddress = address
        serverPort = port
        pool = fakeIPPool
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)

        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, NSEC_PER_SEC, NSEC_PER_SEC)

        dispatch_source_set_event_handler(timer) {
            [weak self] in
            self?.tmr()
        }

        getCurrentDNSServers()
    }

    private func tmr() {
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

    private func lookup(session: DNSSession) {
        RuleManager.currentManager.matchDNS(session, type: .Domain)

        switch session.matchResult! {
        case .Fake:
            guard setUpFakeIP(session) else {
                return
            }
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

    public func inputPacket(packet: NSData, version: NSNumber?) -> Bool {
        guard IPPacket.peekTransportType(packet) == .UDP else {
            return false
        }

        guard IPPacket.peekDestinationAddress(packet) == serverAddress else {
            return false
        }

        guard IPPacket.peekDestinationPort(packet) == serverPort else {
            return false
        }

        guard let ipPacket = IPPacket(datagram: packet) else {
            return false
        }

        guard let session = DNSSession(packet: ipPacket) else {
            return false
        }

        dispatch_async(queue) {
            self.lookup(session)
        }
        return true
    }

    private func outputSession(session: DNSSession) {
        guard let result = session.matchResult else {
            return
        }

        let udpSegment = UDPSegment()
        udpSegment.sourcePort = serverPort
        udpSegment.destinationPort = session.requestIPPacket!.transportSegment.sourcePort
        switch result {
        case .Real:
            udpSegment.payload = session.realResponseMessage!.payload
        case .Fake:
            let response = DNSMessage()
            response.transactionID = session.requestMessage.transactionID
            response.messageType = .Response
            response.recursionAvailable = true
            response.answers.append(DNSResource.ARecord(session.requestMessage.queries[0].name, TTL: 300, address: session.fakeIP!))
            session.expireAt = NSDate().dateByAddingTimeInterval(300)
            guard response.buildMessage() else {
                DDLogError("Failed to build DNS response.")
                return
            }

            udpSegment.payload = response.payload
        default:
            return
        }
        let ipPacket = IPPacket()
        ipPacket.sourceAddress = serverAddress
        ipPacket.destinationAddress = session.requestIPPacket!.sourceAddress
        ipPacket.transportSegment = udpSegment
        ipPacket.transportType = .UDP
        ipPacket.buildPacket()

        outputFunc([ipPacket.datagram], [NSNumber(int: AF_INET)])
    }

    func isFakeIP(ipAddress: IPv4Address) -> Bool {
        return pool.isInPool(ipAddress)
    }

    private func setUpFakeIP(session: DNSSession) -> Bool {
        guard let fakeIP = pool.fetchIP() else {
            DDLogError("Failed to get a fake IP.")
            return false
        }
        session.fakeIP = fakeIP
        fakeSessions[fakeIP] = session
        return true
    }

    public func getCurrentDNSServers() {
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
        guard let message = DNSMessage(payload: data) else {
            DDLogError("Failed to parse response from remote DNS server.")
            return
        }

        dispatch_async(queue) {
            guard let session = self.pendingSessions.removeValueForKey(message.transactionID) else {
                // this should not be a problem if there are multiple DNS servers or the DNS server is hijacked.
                DDLogVerbose("Do not find the corresponding DNS session for the response.")
                return
            }

            session.realResponseMessage = message
            // TODO: response with origin message directly
            // TODO: check return code.
            guard let resolvedAddress = message.resolvedIPv4Address else {
                return
            }
            session.realIP = resolvedAddress

            RuleManager.currentManager.matchDNS(session, type: .IP)

            switch session.matchResult! {
            case .Fake:
                guard self.setUpFakeIP(session) else {
                    return
                }
                self.outputSession(session)
            case .Real:
                self.outputSession(session)
            default:
                DDLogError("The rule match result should never be .Pass or .Unknown in IP mode.")
            }
        }
    }
}

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
