import Foundation


/// This class is not thread-safe.
class SafeDict<T> {
    private var dict: [Int:T] = [:]
    private var curr = 0
    
    var count: Int {
        return dict.count
    }
    
    func insert(value: T) -> UnsafeMutablePointer<Int> {
        let ptr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        ptr.pointee = curr
        dict[curr] = value
        curr += 1
        return ptr
    }
    
    func get(_ id: Int) -> T? {
        return dict[id]
    }
    
    func get(_ id: UnsafePointer<Int>) -> T? {
        return get(id.pointee)
    }

    func remove(_ id: Int) -> T? {
        return dict.removeValue(forKey: id)
    }
    
    func remove(_ id: UnsafeMutablePointer<Int>) -> T? {
        defer {
            id.deallocate(capacity: 1)
        }
        return remove(id.pointee)
    }

}
