import Foundation

protocol StreamCryptoProtocol {
    func update(data: NSData) -> NSData
}
