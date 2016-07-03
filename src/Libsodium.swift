import Foundation
import Sodium

class Libsodium {
    static let initialized: Bool = {
        // this is loaded lasily and also thread-safe
        let _ = sodium_init()
        return true
    }()
}
