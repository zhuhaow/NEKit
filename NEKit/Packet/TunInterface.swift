import Foundation
import tun2socks

class TunInterface: TunInterfaceProtocol {
    func readPackets(completionHandler: ([NSData]) -> ()) {
        NetworkInterface.TunnelProvider.packetFlow.readPacketsWithCompletionHandler {
            completionHandler($0.0)
        }
    }

    func writePackets(packets: [NSData], versions: [Int]) {
        NetworkInterface.TunnelProvider.packetFlow.writePackets(packets, withProtocols: versions)
    }
}
