import Foundation

/// The rule matches every request and returns direct adapter.
///
/// This is equivalent to create an `AllRule` with a `DirectAdapterFactory`.
class DirectRule: AllRule {
    /**
     Create a new `DirectRule` instance.
     */
    init() {
        super.init(adapterFactory: DirectAdapterFactory())
    }
}
