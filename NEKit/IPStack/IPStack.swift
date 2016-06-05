import Foundation
import tun2socks
import CocoaLumberjackSwift

public class IPStack {
    static let sharedStack = IPStack()
    var stacks: [IPStackProtocol] = []

    public init() {}

    public func start() {
        readPackets()
    }

    public func registerStack(stack: IPStackProtocol) {
        stack.outputFunc = generateOutputBlock()
        stacks.append(stack)
    }

    private func readPackets() {
        NetworkInterface.TunnelProvider.packetFlow.readPacketsWithCompletionHandler { packets, versions in
            for (i, packet) in packets.enumerate() {
                for stack in self.stacks {
                    if stack.inputPacket(packet, version: versions[i]) {
                        break
                    }
                }
            }
            self.readPackets()
        }
    }


    private func generateOutputBlock() -> ([NSData], [NSNumber]) -> () {
        return { packets, versions in
            NetworkInterface.TunnelProvider.packetFlow.writePackets(packets, withProtocols: versions)
        }
    }

    public func didAcceptTCPSocket(sock: TSTCPSocket) {
        DDLogDebug("Accepted a new socket from IP stack.")
        let tunSocket = TUNTCPSocket(socket: sock)
        let proxySocket = DirectProxySocket(socket: tunSocket)
        ProxyServer.currentProxy.didAcceptNewSocket(proxySocket)
    }
}
