import Foundation

class Box<T> {
    var value: T

    init(_ value: T) {
        self.value = value
    }
}

class Atomic<T> {
    private var _value: Box<T>
    private let semaphore: dispatch_semaphore_t = dispatch_semaphore_create(1)

    var value: T {
        get {
            return withLock {
                return self._value.value
            }
        }
        set {
            withLock {
                self._value = Box(newValue)
            }
        }
    }

    init(_ value: T) {
        self._value = Box(value)
    }

    private func withLock<U>(block: () -> (U)) -> U {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        defer {
            dispatch_semaphore_signal(semaphore)
        }

        return block()
    }
}
