import Foundation
import NetworkExtension

/// TUN interface provide a scheme to register a set of IP Stacks (implementing `IPStackProtocol`) to process IP packets from a virtual TUN interface.
open class TUNInterface {
    fileprivate weak var packetFlow: NEPacketTunnelFlow?
    fileprivate var stacks: [IPStackProtocol] = []

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
    open func start() {
        readPackets()
    }

    /**
     Stop processing packets, this should be called before releasing the interface.
     */
    open func stop() {
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
    open func registerStack(_ stack: IPStackProtocol) {
        stack.outputFunc = generateOutputBlock()
        stacks.append(stack)
    }

    fileprivate func readPackets() {
        packetFlow?.readPackets { packets, versions in
            for (i, packet) in packets.enumerated() {
                for stack in self.stacks {
                    if stack.inputPacket(packet, version: versions[i]) {
                        break
                    }
                }
            }
            self.readPackets()
        }
    }

    fileprivate func generateOutputBlock() -> ([Data], [NSNumber]) -> () {
        return { [weak self] packets, versions in
            self?.packetFlow?.writePackets(packets, withProtocols: versions)
        }
    }
}
