import Foundation

// This is just a simple wrapper of `Data`.
// Theoratically, it may be better to use a ring buffer for what is needed for this project.
// But this buffer should be much more space efficient.
struct Buffer {
    private var buffer: Data
    private var offset = 0

    var left: Int {
        return buffer.count - offset
    }

    init(capacity: Int) {
        buffer = Data(capacity: capacity)
    }

    mutating func append(data: Data) {
        buffer.append(data)
    }

    mutating func squeeze() {
        guard offset > 0 else {
            return
        }

        buffer.removeFirst(offset)
        offset = 0
    }

    mutating func get(length: Int) -> Data? {
        guard buffer.count - offset >= length else {
            return nil
        }

        defer {
            offset += length
        }

        return buffer.subdata(in: offset..<offset+length)
    }

    mutating func get(to pattern: Data) -> Data? {
        guard let range = buffer.range(of: pattern, options: .backwards, in: offset..<buffer.count) else {
            return nil
        }

        return get(length: range.upperBound - offset)
    }

    mutating func get() -> Data? {
        return get(length: buffer.count - offset)
    }

    mutating func setBack(length: Int) {
        guard offset >= length else {
            offset = 0
            return
        }

        offset -= length
    }

    mutating func release() {
        buffer = Data()
    }

    mutating func withUnsafeBytes<T, U>(_ body: @escaping (UnsafePointer<T>) throws -> U ) rethrows -> U {
        let c = buffer.count - offset
        let o = offset

        return try buffer.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> U in
            return try body(ptr.baseAddress!.advanced(by: o).bindMemory(to: T.self, capacity: c / MemoryLayout<T>.stride))
        }
    }

    mutating func skip(_ step: Int) {
        offset += step
    }
}
