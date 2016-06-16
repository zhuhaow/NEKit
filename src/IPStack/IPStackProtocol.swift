import Foundation

public protocol IPStackProtocol: class {
    func inputPacket(packet: NSData, version: NSNumber?) -> Bool
    var outputFunc: (([NSData], [NSNumber]) -> ())! { get set }
}
