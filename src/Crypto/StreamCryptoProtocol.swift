import Foundation

public protocol StreamCryptoProtocol {
    func update(data: NSData) -> NSData
}
