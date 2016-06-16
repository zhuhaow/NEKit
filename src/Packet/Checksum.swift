import Foundation

class Checksum {

    static func computeChecksum(data: NSData, from start: Int = 0, to end: Int? = nil, withPseudoHeaderChecksum initChecksum: UInt32 = 0) -> UInt16 {
        return toChecksum(computeChecksumUnfold(data, from: start, to: end, withPseudoHeaderChecksum: initChecksum))
    }

    static func validateChecksum(payload: NSData, from start: Int = 0, to end: Int? = nil) -> Bool {
        let cs = computeChecksumUnfold(payload, from: start, to: end)
        return toChecksum(cs) == 0
    }

    static func computeChecksumUnfold(data: NSData, from start: Int = 0, to end: Int? = nil, withPseudoHeaderChecksum initChecksum: UInt32 = 0) -> UInt32 {
        let scanner = BinaryDataScanner(data: data, littleEndian: true)
        scanner.skipTo(start)
        var result: UInt32 = initChecksum
        var end = end
        if end == nil {
            end = data.length
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


    static func toChecksum(checksum: UInt32) -> UInt16 {
        var result = checksum
        while (result) >> 16 != 0 {
            result = result >> 16 + result & 0xFFFF
        }
        return ~UInt16(result)
    }
}
