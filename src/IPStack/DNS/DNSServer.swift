import Foundation
import NetworkExtension
import CocoaLumberjackSwift

/// A DNS server designed as an `IPStackProtocol` implemention which works with TUN interface.
///
/// This class is thread-safe.
public class DNSServer: DNSResolverDelegate, IPStackProtocol {
    /// Current DNS server.
    ///
    /// - warning: There is at most one DNS server running at the same time. If a DNS server is registered to `TUNInterface` then it must also be set here.
    public static var currentServer: DNSServer?

    /// The address of DNS server.
    let serverAddress: IPv4Address

    /// The port of DNS server
    let serverPort: Port

    private let queue: dispatch_queue_t = dispatch_queue_create("NEKit.DNSServer", DISPATCH_QUEUE_SERIAL)
    private var fakeSessions: [IPv4Address: DNSSession] = [:]
    private var pendingSessions: [UInt16: DNSSession] = [:]
    private let pool: IPv4Pool?
    private var resolvers: [DNSResolverProtocol] = []

    public var outputFunc: (([NSData], [NSNumber]) -> ())!

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
    private func cleanUp(address: IPv4Address, after delay: Int) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay) * Int64(NSEC_PER_SEC)), queue) {
            [weak self] in
            self?.fakeSessions.removeValueForKey(address)
            self?.pool?.releaseIP(address)
        }
    }

    private func lookup(session: DNSSession) {
        RuleManager.currentManager.matchDNS(session, type: .Domain)

        switch session.matchResult! {
        case .Fake:
            guard setUpFakeIP(session) else {
                // failed to set up a fake IP, return the result directly
                session.matchResult = .Real
                lookupRemotely(session)
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
    public func inputPacket(packet: NSData, version: NSNumber?) -> Bool {
        guard IPPacket.peekProtocol(packet) == .UDP else {
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

        dispatch_async(queue) {
            self.lookup(session)
        }
        return true
    }

    public func stop() {
        for resolver in resolvers {
            resolver.stop()
        }
        resolvers = []

        // The blocks scheduled with `dispatch_after` are ignored since they are hard to cancel. But there should be no consequence, everything will be released except for a few `IPAddress`es and the `queue` which will be released later.
    }

    private func outputSession(session: DNSSession) {
        guard let result = session.matchResult else {
            return
        }

        let udpParser = UDPProtocolParser()
        udpParser.sourcePort = serverPort
        // swiftlint:disable:next force_cast
        udpParser.destinationPort = (session.requestIPPacket!.protocolParser as! UDPProtocolParser).sourcePort
        switch result {
        case .Real:
            udpParser.payload = session.realResponseMessage!.payload
        case .Fake:
            let response = DNSMessage()
            response.transactionID = session.requestMessage.transactionID
            response.messageType = .Response
            response.recursionAvailable = true
            response.answers.append(DNSResource.ARecord(session.requestMessage.queries[0].name, TTL: UInt32(Opt.DNSFakeIPTTL), address: session.fakeIP!))
            session.expireAt = NSDate().dateByAddingTimeInterval(Double(Opt.DNSFakeIPTTL))
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
        ipPacket.transportProtocol = .UDP
        ipPacket.buildPacket()

        outputFunc([ipPacket.packetData], [NSNumber(int: AF_INET)])
    }

    func isFakeIP(ipAddress: IPv4Address) -> Bool {
        return pool?.isInPool(ipAddress) ?? false
    }

    func lookupFakeIP(address: IPv4Address) -> DNSSession? {
        var session: DNSSession?
        dispatch_sync(queue) {
            session = self.fakeSessions[address]
        }
        return session
    }

    /**
     Add new DNS resolver to DNS server.

     - parameter resolver: The resolver to add.
     */
    public func registerResolver(resolver: DNSResolverProtocol) {
        resolver.delegate = self
        resolvers.append(resolver)
    }

    private func setUpFakeIP(session: DNSSession) -> Bool {

        guard let fakeIP = pool?.fetchIP() else {
            DDLogVerbose("Failed to get a fake IP.")
            return false
        }
        session.fakeIP = fakeIP
        fakeSessions[fakeIP] = session
        session.expireAt = NSDate().dateByAddingTimeInterval(NSTimeInterval(Opt.DNSFakeIPTTL))
        // keep the fake session for 2 TTL
        cleanUp(fakeIP, after: Opt.DNSFakeIPTTL * 2)
        return true
    }

    public func didReceiveResponse(rawResponse: NSData) {
        guard let message = DNSMessage(payload: rawResponse) else {
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

            // TODO: check return code.
            guard let resolvedAddress = message.resolvedIPv4Address else {
                session.matchResult = .Real
                self.outputSession(session)
                return
            }
            session.realIP = resolvedAddress

            if session.matchResult != .Fake && session.matchResult != .Real {
                RuleManager.currentManager.matchDNS(session, type: .IP)
            }

            switch session.matchResult! {
            case .Fake:
                if !self.setUpFakeIP(session) {
                    // return real response
                    session.matchResult = .Real
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
