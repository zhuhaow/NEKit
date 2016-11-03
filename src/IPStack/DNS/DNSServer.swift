import Foundation
import NetworkExtension
import CocoaLumberjackSwift

/// A DNS server designed as an `IPStackProtocol` implemention which works with TUN interface.
///
/// This class is thread-safe.
open class DNSServer: DNSResolverDelegate, IPStackProtocol {
    /// Current DNS server.
    ///
    /// - warning: There is at most one DNS server running at the same time. If a DNS server is registered to `TUNInterface` then it must also be set here.
    open static var currentServer: DNSServer?

    /// The address of DNS server.
    let serverAddress: IPv4Address

    /// The port of DNS server
    let serverPort: Port

    fileprivate let queue: DispatchQueue = DispatchQueue(label: "NEKit.DNSServer", attributes: [])
    fileprivate var fakeSessions: [IPv4Address: DNSSession] = [:]
    fileprivate var pendingSessions: [UInt16: DNSSession] = [:]
    fileprivate let pool: IPv4Pool?
    fileprivate var resolvers: [DNSResolverProtocol] = []

    open var outputFunc: (([Data], [NSNumber]) -> ())!

    // Only match A record as of now, all other records should be passed directly.
    fileprivate let matchedType = [DNSType.a]

    /**
     Initailize a DNS server.

     - parameter address:    The IP address of the server.
     - parameter port:       The listening port of the server.
     - parameter fakeIPPool: The pool of fake IP addresses. Set to nil if no fake IP is needed.
     */
    public init(address: IPv4Address, port: Port, fakeIPPool: IPv4Pool? = nil) {
        serverAddress = address
        serverPort = port
        pool = fakeIPPool
    }

    /**
     Clean up fake IP.

     - parameter address: The fake IP address.
     - parameter delay:   How long should the fake IP be valid.
     */
    fileprivate func cleanUpFakeIP(_ address: IPv4Address, after delay: Int) {
        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(delay) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            [weak self] in
            _ = self?.fakeSessions.removeValue(forKey: address)
            self?.pool?.releaseIP(address)
        }
    }

    /**
     Clean up pending session.

     - parameter session: The pending session.
     - parameter delay:   How long before the pending session be cleaned up.
     */
    fileprivate func cleanUpPendingSession(_ session: DNSSession, after delay: Int) {
        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(delay) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            [weak self] in
            _ = self?.pendingSessions.removeValue(forKey: session.requestMessage.transactionID)
        }
    }

    fileprivate func lookup(_ session: DNSSession) {
        guard shouldMatch(session) else {
            session.matchResult = .real
            lookupRemotely(session)
            return
        }

        RuleManager.currentManager.matchDNS(session, type: .domain)

        switch session.matchResult! {
        case .fake:
            guard setUpFakeIP(session) else {
                // failed to set up a fake IP, return the result directly
                session.matchResult = .real
                lookupRemotely(session)
                return
            }
            outputSession(session)
        case .real, .unknown:
            lookupRemotely(session)
        default:
            DDLogError("The rule match result should never be .Pass.")
        }
    }

    fileprivate func lookupRemotely(_ session: DNSSession) {
        pendingSessions[session.requestMessage.transactionID] = session
        cleanUpPendingSession(session, after: Opt.DNSPendingSessionLifeTime)
        sendQueryToRemote(session)
    }

    fileprivate func sendQueryToRemote(_ session: DNSSession) {
        for resolver in resolvers {
            resolver.resolve(session)
        }
    }

    /**
     Input IP packet into the DNS server.

     - parameter packet:  The IP packet.
     - parameter version: The version of the IP packet.

     - returns: If the packet is taken in by this DNS server.
     */
    open func inputPacket(_ packet: Data, version: NSNumber?) -> Bool {
        guard IPPacket.peekProtocol(packet) == .udp else {
            return false
        }

        guard IPPacket.peekDestinationAddress(packet) == serverAddress else {
            return false
        }

        guard IPPacket.peekDestinationPort(packet) == serverPort else {
            return false
        }

        guard let ipPacket = IPPacket(packetData: packet) else {
            return false
        }

        guard let session = DNSSession(packet: ipPacket) else {
            return false
        }

        queue.async {
            self.lookup(session)
        }
        return true
    }

    open func stop() {
        for resolver in resolvers {
            resolver.stop()
        }
        resolvers = []

        // The blocks scheduled with `dispatch_after` are ignored since they are hard to cancel. But there should be no consequence, everything will be released except for a few `IPAddress`es and the `queue` which will be released later.
    }

    fileprivate func outputSession(_ session: DNSSession) {
        guard let result = session.matchResult else {
            return
        }

        let udpParser = UDPProtocolParser()
        udpParser.sourcePort = serverPort
        // swiftlint:disable:next force_cast
        udpParser.destinationPort = (session.requestIPPacket!.protocolParser as! UDPProtocolParser).sourcePort
        switch result {
        case .real:
            udpParser.payload = session.realResponseMessage!.payload
        case .fake:
            let response = DNSMessage()
            response.transactionID = session.requestMessage.transactionID
            response.messageType = .response
            response.recursionAvailable = true
            // since we only support ipv4 as of now, it must be an answer of type A
            response.answers.append(DNSResource.ARecord(session.requestMessage.queries[0].name, TTL: UInt32(Opt.DNSFakeIPTTL), address: session.fakeIP!))
            session.expireAt = Date().addingTimeInterval(Double(Opt.DNSFakeIPTTL))
            guard response.buildMessage() else {
                DDLogError("Failed to build DNS response.")
                return
            }

            udpParser.payload = response.payload
        default:
            return
        }
        let ipPacket = IPPacket()
        ipPacket.sourceAddress = serverAddress
        ipPacket.destinationAddress = session.requestIPPacket!.sourceAddress
        ipPacket.protocolParser = udpParser
        ipPacket.transportProtocol = .udp
        ipPacket.buildPacket()

        outputFunc([ipPacket.packetData], [NSNumber(value: AF_INET as Int32)])
    }

    fileprivate func shouldMatch(_ session: DNSSession) -> Bool {
        return matchedType.contains(session.requestMessage.type!)
    }

    func isFakeIP(_ ipAddress: IPv4Address) -> Bool {
        return pool?.isInPool(ipAddress) ?? false
    }

    func lookupFakeIP(_ address: IPv4Address) -> DNSSession? {
        var session: DNSSession?
        queue.sync {
            session = self.fakeSessions[address]
        }
        return session
    }

    /**
     Add new DNS resolver to DNS server.

     - parameter resolver: The resolver to add.
     */
    open func registerResolver(_ resolver: DNSResolverProtocol) {
        resolver.delegate = self
        resolvers.append(resolver)
    }

    fileprivate func setUpFakeIP(_ session: DNSSession) -> Bool {

        guard let fakeIP = pool?.fetchIP() else {
            DDLogVerbose("Failed to get a fake IP.")
            return false
        }
        session.fakeIP = fakeIP
        fakeSessions[fakeIP] = session
        session.expireAt = Date().addingTimeInterval(TimeInterval(Opt.DNSFakeIPTTL))
        // keep the fake session for 2 TTL
        cleanUpFakeIP(fakeIP, after: Opt.DNSFakeIPTTL * 2)
        return true
    }

    open func didReceiveResponse(_ rawResponse: Data) {
        guard let message = DNSMessage(payload: rawResponse) else {
            DDLogError("Failed to parse response from remote DNS server.")
            return
        }

        queue.async {
            guard let session = self.pendingSessions.removeValue(forKey: message.transactionID) else {
                // this should not be a problem if there are multiple DNS servers or the DNS server is hijacked.
                DDLogVerbose("Do not find the corresponding DNS session for the response.")
                return
            }

            session.realResponseMessage = message

            session.realIP = message.resolvedIPv4Address

            if session.matchResult != .fake && session.matchResult != .real {
                RuleManager.currentManager.matchDNS(session, type: .ip)
            }

            switch session.matchResult! {
            case .fake:
                if !self.setUpFakeIP(session) {
                    // return real response
                    session.matchResult = .real
                }
                self.outputSession(session)
            case .real:
                self.outputSession(session)
            default:
                DDLogError("The rule match result should never be .Pass or .Unknown in IP mode.")
            }
        }
    }
}
