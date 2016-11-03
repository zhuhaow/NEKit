import Foundation

/// The rule matches every request and returns direct adapter.
///
/// This is equivalent to create an `AllRule` with a `DirectAdapterFactory`.
open class DirectRule: AllRule {
    open override var description: String {
        return "<DirectRule>"
    }
    /**
     Create a new `DirectRule` instance.
     */
    public init() {
        super.init(adapterFactory: DirectAdapterFactory())
    }
}
