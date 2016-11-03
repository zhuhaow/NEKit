import Foundation

/// This is just a wrapper as a work around since there is no way to change a passed-in value in a block.
open class Box<T> {
    /// The underlying value.
    open var value: T

    /**
     Init the `Box`.

     - parameter value: The variable to be wrapped in.
     */
    init(_ value: T) {
        self.value = value
    }
}

/// Atomic provides thread-safety to access a variable.
open class Atomic<T> {
    fileprivate var _value: Box<T>
    fileprivate let semaphore: DispatchSemaphore = DispatchSemaphore(value: 1)

    /// The thread-safe variable.
    open var value: T {
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
     The provides a scheme to access and change the underlying variable in a block.

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
    open func withBox<U>(_ block: (Box<T>) -> (U)) -> U {
        return withLock {
            return block(self._value)
        }
    }

    fileprivate func withLock<U>(_ block: () -> (U)) -> U {
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)

        defer {
            semaphore.signal()
        }

        return block()
    }
}
