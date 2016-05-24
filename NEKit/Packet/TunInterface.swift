import Foundation
import tun2socks

class TunInterface: TunInterfaceProtocol {
    func readPackets(completionHandler: ([NSData]?, NSError?) -> ()) {
        NetworkInterface.TunnelProvider.packetFlow.readPacketsWithCompletionHandler {
            completionHandler($0.0, nil)
        }
    }

    func writePackets(packets: [NSData]) {
        NetworkInterface.TunnelProvider.packetFlow.writePackets(packets, withProtocols: Array<NSNumber>(count: packets.count, repeatedValue: NSNumber(int: AF_INET)))
    }
}
