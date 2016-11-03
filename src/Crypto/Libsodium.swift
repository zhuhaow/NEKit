import Foundation
import Sodium

open class Libsodium {
    /// This must be accessed at least once before Libsodium is used.
    open static let initialized: Bool = {
        // this is loaded lasily and also thread-safe
        _ = sodium_init()
        return true
    }()
}
