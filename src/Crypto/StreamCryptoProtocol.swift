import Foundation

public protocol StreamCryptoProtocol {
    func update(_ data: inout Data)
}
