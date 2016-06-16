import Foundation

class Atomic<T> {
    var _value: T
    let semaphore: dispatch_semaphore_t = dispatch_semaphore_create(1)

    var value: T {
        get {
            return withLock {
                return self._value
            }
        }
        set {
            withLock {
                self._value = newValue
            }
        }
    }

    init(value: T) {
        self._value = value
    }

    private func withLock<U>(block: () -> (U)) -> U {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        defer {
            dispatch_semaphore_signal(semaphore)
        }

        return block()
    }
}
