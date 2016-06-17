import Foundation

/// This is just a wrapper as a work around since there is no way to change a passed-in value in a block.
public class Box<T> {
    /// The underlying value.
    public var value: T

    /**
     Init the `Box`.

     - parameter value: The variable to be wrapped in.
     */
    init(_ value: T) {
        self.value = value
    }
}

/// Atomic provides thread-safety to access a variable.
public class Atomic<T> {
    private var _value: Box<T>
    private let semaphore: dispatch_semaphore_t = dispatch_semaphore_create(1)

    /// The thread-safe variable.
    public var value: T {
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

    /**
     Init the `Atomic` to access the variable in a thread-safe way.

     - parameter value: The variable needs to be thread-safe.
     */
    public init(_ value: T) {
        self._value = Box(value)
    }

    /**
     The provides a scheme to access the underlying variable in a block.

     The variable can be accessed with `Box<T>.value` as:

     ```
     let atomic = Atomic([1,2,3])
     atomic.withBox { array in
        array.value.append(4)
        return array.value.reduce(0, combine: +)
     }
     ```

     - parameter block: The code to run with the variable wrapped in a `Box`.

     - returns: Any value returned by the block.
     */
    public func withBox<U>(block: (Box<T>) -> (U)) -> U {
        return withLock {
            return block(self._value)
        }
    }

    private func withLock<U>(block: () -> (U)) -> U {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        defer {
            dispatch_semaphore_signal(semaphore)
        }

        return block()
    }
}
