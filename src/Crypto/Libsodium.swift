import Foundation
import Sodium

public class Libsodium {
    /// This must be accessed at least once before Libsodium is used.
    public static let initialized: Bool = {
        // this is loaded lasily and also thread-safe
        let _ = sodium_init()
        return true
    }()
}
