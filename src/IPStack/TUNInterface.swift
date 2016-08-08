import Foundation
import NetworkExtension
import CocoaLumberjackSwift

/// TUN interface provide a scheme to register a set of IP Stacks (implementing `IPStackProtocol`) to process IP packets from a virtual TUN interface.
public class TUNInterface {
    private weak var packetFlow: NEPacketTunnelFlow?
    private var stacks: [IPStackProtocol] = []

    /**
     Initialize TUN interface with a packet flow.

     - parameter packetFlow: The packet flow to work with.
     */
    public init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }

    /**
     Start processing packets, this should be called after registering all IP stacks.

     A stopped interface should never start again. Create a new interface instead.
     */
    public func start() {
        readPackets()
    }

    /**
     Stop processing packets, this should be called before releasing the interface.
     */
    public func stop() {
        packetFlow = nil

        for stack in stacks {
            stack.stop()
        }
        stacks = []
    }

    /**
     Register a new IP stack.

     When a packet is read from TUN interface (the packet flow), it is passed into each IP stack according to the registration order until one of them takes it in.

     - parameter stack: The IP stack to append to the stack list.
     */
    public func registerStack(stack: IPStackProtocol) {
        stack.outputFunc = generateOutputBlock()
        stacks.append(stack)
    }

    private func readPackets() {
        packetFlow?.readPacketsWithCompletionHandler { packets, versions in
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
        return { [weak self] packets, versions in
            self?.packetFlow?.writePackets(packets, withProtocols: versions)
        }
    }
}
