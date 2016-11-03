import Foundation

open class Observer<T: EventType> {
    public init() {}
    open func signal(_ event: T) {}
}
