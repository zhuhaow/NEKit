import Foundation

protocol IPStackProtocol {
    func inputPacket(packet: NSData, version: NSNumber?) -> Bool
    var outputFunc: (([NSData], [NSNumber]) -> ())! { get set }
}
