import Foundation
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func <= <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l <= r
  default:
    return !(rhs < lhs)
  }
}


open class Checksum {

    open static func computeChecksum(_ data: Data, from start: Int = 0, to end: Int? = nil, withPseudoHeaderChecksum initChecksum: UInt32 = 0) -> UInt16 {
        return toChecksum(computeChecksumUnfold(data, from: start, to: end, withPseudoHeaderChecksum: initChecksum))
    }

    open static func validateChecksum(_ payload: Data, from start: Int = 0, to end: Int? = nil) -> Bool {
        let cs = computeChecksumUnfold(payload, from: start, to: end)
        return toChecksum(cs) == 0
    }

    open static func computeChecksumUnfold(_ data: Data, from start: Int = 0, to end: Int? = nil, withPseudoHeaderChecksum initChecksum: UInt32 = 0) -> UInt32 {
        let scanner = BinaryDataScanner(data: data, littleEndian: true)
        scanner.skip(to: start)
        var result: UInt32 = initChecksum
        var end = end
        if end == nil {
            end = data.count
        }
        while scanner.position + 2 <= end {
            let value = scanner.read16()!
            result += UInt32(value)
        }

        if scanner.position != end {
            // data is of odd size
            // Intel and ARM are both litten endian
            // so just add it
            let value = scanner.readByte()!
            result += UInt32(value)
        }
        return result
    }


    open static func toChecksum(_ checksum: UInt32) -> UInt16 {
        var result = checksum
        while (result) >> 16 != 0 {
            result = result >> 16 + result & 0xFFFF
        }
        return ~UInt16(result)
    }
}
