import Foundation

/// The protocol defines an IP stack.
public protocol IPStackProtocol: class {
    /**
     Input a packet into the stack.

     - parameter packet:  The IP packet.
     - parameter version: The version of the IP packet, i.e., AF_INET, AF_INET6.

     - returns: If the stack takes in this packet. If the packet is taken in, then it won't be processed by other IP stacks.
     */
    func input(packet: Data, version: NSNumber?) -> Bool

    /// This is called when this stack decided to output some IP packet. This is set automatically when the stack is registered to some interface.
    ///
    /// The parameter is the safe as the `inputPacket`.
    ///
    /// - note: This block is thread-safe.
    var outputFunc: (([Data], [NSNumber]) -> Void)! { get set }

    func start()
    
    /**
     Stop the stack from running.

     This is called when the interface this stack is registered to stop to processing packets and will be released soon.
     */
    func stop()
}

extension IPStackProtocol {
    public func stop() {}
}
