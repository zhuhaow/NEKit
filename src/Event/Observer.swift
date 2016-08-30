import Foundation

public class Observer<T: EventType> {
    public init() {}
    public func signal(event: T) {}
}
