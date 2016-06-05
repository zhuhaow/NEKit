import Foundation
import tun2socks
import CocoaLumberjackSwift

public class IPStack {
    var stacks: [IPStackProtocol] = []

    public init() {}

    public func start() {
//        // start reading packets
//        NetworkInterface.TunnelProvider.packetFlow.readPacketsWithCompletionHandler {
//            for (i, version) in $1.enumerate() {
//                if version == 6 {
//                    // ignore all IPv6 packets for now
//                    break
//                }
//
//                if let type = IPPacket.peekTransportType($0[i]) {
//                    switch type {
//                    case .TCP:
//                        TUNIPStack.stack.receivedPacket($0[i])
//                    case .UDP:
//                        // check if it is DNS query, discard otherwise (just for now)
//                        break
//                    case .ICMP:
//                        break
//                    }
//                }
//            }
//        }
    }

    public func didAcceptTCPSocket(sock: TSTCPSocket) {
        DDLogDebug("Accepted a new socket from IP stack.")
        let tunSocket = TUNTCPSocket(socket: sock)
        let proxySocket = DirectProxySocket(socket: tunSocket)
        ProxyServer.currentProxy.didAcceptNewSocket(proxySocket)
    }
}
