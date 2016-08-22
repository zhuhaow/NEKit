import Foundation

public class Observer<T: EventType> {
    public func signal(event: T) {}
}
