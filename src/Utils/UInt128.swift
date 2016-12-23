//
// UInt128.swift
//
// An implementation of a 128-bit unsigned integer data type not
// relying on any outside libraries apart from Swift's standard
// library. It also seeks to implement the entirety of the
// UnsignedInteger protocol as well as standard functions supported
// by Swift's native unsigned integer types.
//
// Copyright 2016 Joel Gerber
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

// https://github.com/Jitsusama/UInt128

// MARK: Error Type
/// An `ErrorType` for `UInt128` data types. It includes cases
/// for the 4 possible errors that can occur during string
/// conversion, and 1 impossible error to satisfy a default
/// case in a switch statement.
public enum UInt128Errors: Error {
    /// Invalid character supplied in input string.
    case invalidStringCharacter
    /// Invalid radix given for conversion.
    case invalidRadix
    /// Cannot convert an empty string into a UInt128 value.
    case emptyString
    /// The unsigned integer representation of string exceeds
    /// 128 bits.
    case stringInputOverflow
}
// MARK: Data Type
/// A 128-bit unsigned integer value type.
/// Storage is based upon a tuple of 2, 64-bit unsigned integers.
public struct UInt128 {
    // MARK: Type Properties
    /// The largest value a UInt128 can hold.
    public static var max: UInt128 {
        return UInt128(upperBits: UInt64.max, lowerBits: UInt64.max)
    }
    /// The smallest value a UInt128 can hold.
    public static var min: UInt128 {
        return UInt128(upperBits: 0, lowerBits: 0)
    }
    /// Returns size of data type in bits.
    public static var _sizeInBits: Int32 {
        return 128
    }
    /// Returns size of data type in bytes.
    public static var _sizeInBytes: Int32 {
        return 128 / 8
    }
    // MARK: Instance Properties
    /// Internal value is presented as a tuple of 2 64-bit
    /// unsigned integers.
    internal var value: (upperBits: UInt64, lowerBits: UInt64) = (0, 0)
    /// Counts up the significant bits in stored data.
    public var significantBits: UInt128 {
        // Will turn into final result.
        var significantBitCount: UInt128 = 0
        // The bits to crawl in loop.
        var bitsToWalk: UInt64 = 0
        if self.value.upperBits > 0 {
            bitsToWalk = self.value.upperBits
            // When upperBits > 0, lowerBits are all significant.
            significantBitCount += 64
        } else if self.value.lowerBits > 0 {
            bitsToWalk = self.value.lowerBits
        }
        // Walk significant bits by shifting right until all bits are equal to 0.
        while bitsToWalk > 0 {
            bitsToWalk >>= 1
            significantBitCount += 1
        }
        return significantBitCount
    }
    /// Returns the big-endian representation of the integer, changing the byte order if necessary.
    public var bigEndian: UInt128 {
        #if arch(i386) || arch(x86_64) || arch(arm) || arch(arm64)
            return byteSwapped
        #else
            return self
        #endif
    }
    /// Returns the little-endian representation of the integer, changing the byte order if necessary.
    public var littleEndian: UInt128 {
        #if arch(i386) || arch(x86_64) || arch(arm) || arch(arm64)
            return self
        #else
            return byteSwapped
        #endif
    }
    /// Returns the current integer with the byte order swapped.
    public var byteSwapped: UInt128 {
        var result: UInt128 = 0
        // Swap endian (big to little) or (little to big)
        var bytes = [UInt128].init(repeating: 0, count: 16)
        // Used in for loop to mask and shift our stored value.
        var byteMask: UInt128 = 0xff
        var byteShift: UInt128 = 120
        // Loop through each of our 16 bytes.
        for index in 0 ..< bytes.count {
            if byteMask <= 0xff << 56 {
                // The bottom 8 bytes will get masked and shifted to opposing byte.
                bytes[index] = (self & byteMask) << byteShift
                // Don't decrease the shifter on the bottom half's last byte, as this
                // down shift will become the up shift during the next for loop run.
                if byteMask != 0xff << 56 {
                    byteShift -= 16
                }
                byteMask <<= 8
            } else if byteMask >= (0xff << 63) << 1 {
                // The top 8 bytes will get masked and shifted to opposing byte.
                bytes[index] = (self & byteMask) >> byteShift
                byteMask <<= 8
                byteShift += 16
            }
            // Cheap way to add the results together.
            result |= bytes[index]
        }
        return result
    }
    // MARK: Type Methods
    /// Create a UInt128 instance from the supplied string.
    /// - requires:
    ///     `string` must match the following patterns:
    ///     `/0x[0-9a-fA-F]+/` for hexadecimal, `/[0-9]+/` for decimal,
    ///     `/0o[0-7]+/` for octal or `/0b[01]+/` for binary.
    /// - parameter string:
    ///     A string representation of a number in one of the supported
    ///     radix types (base 16, 10, 8 or 2).
    /// - returns:
    ///     Returns a valid UInt128 instance.
    /// - throws:
    ///      A `UInt128Errors` ErrorType.
    internal static func fromUnparsedString(_ string: String) throws -> UInt128 {
        // Empty string is bad.
        guard !string.isEmpty else {
            throw UInt128Errors.emptyString
        }
        // Internal variables.
        let radix: UInt8
        var builtString = String()
        // Determine radix based upon number prefix.
        if string.hasPrefix("0b") { // binary
            radix = 2
        } else if string.hasPrefix("0o") { // octal
            radix = 8
        } else if string.hasPrefix("0x") { // hex
            radix = 16
        } else { // default to decimal.
            radix = 10
        }
        // Used to hold passed string with radix removed.
        var stringSansRadix = string
        // Remove the radix identifier from the front of the string.
        if radix != 10 {
            stringSansRadix.removeSubrange(string.startIndex...string.characters.index(string.startIndex, offsetBy: 1))
        }
        // Lowercase the string for normalization purposes.
        stringSansRadix = stringSansRadix.lowercased()
        // Filter string for valid digits and build into a new string.
        for character in stringSansRadix.characters {
            switch character {
            case "0"..."1": // Digits specific to all numbering systems.
                builtString.append(character)
            case "2"..."7": // Digits specific to octal, decimal and hexadecimal.
                guard radix == 8 || radix == 10 || radix == 16 else {
                    throw UInt128Errors.invalidStringCharacter
                }
                builtString.append(character)
            case "8"..."9": // Digits specific to decimal and hexadecimal.
                guard radix == 10 || radix == 16 else {
                    throw UInt128Errors.invalidStringCharacter
                }
                builtString.append(character)
            case "a"..."f": // Digits specific to hexadecimal.
                guard radix == 16 else {
                    throw UInt128Errors.invalidStringCharacter
                }
                builtString.append(character)
            default:
                throw UInt128Errors.invalidStringCharacter
            }
        }
        // Remove any leading 0s.
        for character in builtString.characters {
            if character == "0" {
                builtString.remove(at: builtString.startIndex)
            } else {
                break
            }
        }
        // Pass parsed string to factory function.
        return try UInt128.fromParsedString(builtString.utf16, radix: radix)
    }
    /// Returns a newly instantiated UInt128 type from a pre-parsed and safe string.
    /// This should not be called directly, refer to `fromUnparsedString` for a proper
    /// front-end method.
    /// - requires:
    ///     `string` must match the pattern `/[0-9a-z]+/`.
    /// - parameter string:
    ///     A string representation of a number in one of the supported
    ///     radix types (base 2-36).
    /// - parameter radix:
    ///     The radix of the numbering system the `string` parameter
    ///     is encoded by.
    /// - returns:
    ///     Returns a valid UInt128 instance.
    /// - throws:
    ///      A `UInt128Errors` ErrorType.
    internal static func fromParsedString(_ string: String.UTF16View, radix: UInt8) throws -> UInt128 {
        var result: UInt128 = 0
        // Define ranges. Used to convert character value to numeric later.
        let digit = "0".utf16.first!..."9".utf16.first!
        let lower = "a".utf16.first!..."z".utf16.first!
        // radix cannot exceed basic number and [a-z] character set count.
        guard radix <= UInt8(digit.count + lower.count) else {
            throw UInt128Errors.invalidRadix
        }
        // Loop through each charcter's CodeUnit value.
        for character in string {
            var current: UInt128 = 0
            // For each CodeUnit value, convert to a "decimal" value.
            switch character {
            case digit: current = UInt128(character - digit.lowerBound)
            case lower: current = UInt128(character - lower.lowerBound) + 10
            default: throw UInt128Errors.invalidStringCharacter
            }
            // Make room for current positional value.
            let (multiplyResult, multiplyOverflow) = UInt128.multiplyWithOverflow(
                result, UInt128(radix)
            )
            // Add current value to temporary result.
            let (addResult, addOverflow) = UInt128.addWithOverflow(
                multiplyResult, current
            )
            // We don't desire handling overflows during string conversion.
            guard !multiplyOverflow && !addOverflow else {
                throw UInt128Errors.stringInputOverflow
            }
            result = addResult
        }
        return result
    }
    // MARK: Initialization
    public init() {
        value.lowerBits = 0
        value.upperBits = 0
    }
    public init(_ value: UInt128) {
        self.value = value.value
    }
    public init(upperBits: UInt64, lowerBits: UInt64) {
        value.upperBits = upperBits
        value.lowerBits = lowerBits
    }
    public init(_ value: Int) {
        self.init()
        self.value.lowerBits = UInt64(value)
    }
    public init(_ value: String) throws {
        try self = UInt128.fromUnparsedString(value)
    }
    /// Creates an integer from its big-endian representation, changing the
    /// byte order if necessary.
    public init(bigEndian value: UInt128) {
        #if arch(i386) || arch(x86_64) || arch(arm) || arch(arm64)
            self = value.byteSwapped
        #else
            self = value
        #endif
    }
    /// Creates an integer from its little-endian representation, changing the
    /// byte order if necessary.
    public init(littleEndian value: UInt128) {
        #if arch(i386) || arch(x86_64) || arch(arm) || arch(arm64)
            self = value
        #else
            self = value.byteSwapped
        #endif
    }
    // MARK: Instance Methods
    /// Converts the stored value into a string representation.
    /// - parameter radix:
    ///     The radix for the base numbering system you wish to have
    ///     the type presented in.
    /// - parameter uppercase:
    ///     Determines whether letter components of the outputted string will be in
    ///     uppercase format or not.
    /// - returns:
    ///     String representation of the stored UInt128 value.
    internal func toString(radix: Int = 10, uppercase: Bool = true) -> String {
        precondition(radix > 1 && radix < 17, "radix must be within the range of 2-16.")
        // Will store the final string result.
        var result = String()
        // Simple case.
        if self == 0 {
            result.append("0")
            return result
        }
        // Used as the check for indexing through UInt128 for string interpolation.
        var divmodResult = (quotient: self, remainder: UInt128(0))
        // Will hold the pool of possible values.
        let characterPool = (uppercase) ? "0123456789ABCDEF" : "0123456789abcdef"
        // Go through internal value until every base position is string(ed).
        repeat {
            divmodResult = divmodResult.quotient /% UInt128(radix)
            let index = characterPool.characters.index(characterPool.startIndex, offsetBy: Int(divmodResult.remainder))
            result.insert(characterPool[index], at: result.startIndex)
        } while divmodResult.quotient > 0
        return result
    }
}
// MARK: - UnsignedIntegerType
extension UInt128: UnsignedInteger {
    public init(_ value: UIntMax) {
        self.init()
        self.value.lowerBits = value
    }
    public init(_ value: UInt) {
        self.init(value.toUIntMax())
    }
    public init(_ value: UInt8) {
        self.init(value.toUIntMax())
    }
    public init(_ value: UInt16) {
        self.init(value.toUIntMax())
    }
    public init(_ value: UInt32) {
        self.init(value.toUIntMax())
    }
    public func toUIntMax() -> UIntMax {
        return UIntMax(value.lowerBits)
    }
    // MARK: Hashable Conformance
    public var hashValue: Int {
        return Int(
            value.lowerBits.hashValue ^ value.upperBits.hashValue
        )
    }
    // MARK: ForwardIndexType Conformance
    public func successor() -> UInt128 {
        return self &+ 1
    }
    // MARK: BidirectionalIndexType Conformance
    public func predecessor() -> UInt128 {
        return self &- 1
    }
}
// MARK: - Strideable
extension UInt128: Strideable {
    public typealias Stride = Int
    /// Returns an instance of UInt128 that is the current instance's
    /// value increased by `n` when `n` is positive or decreased
    /// by `n` when `n` is negative.
    public func advancedBy(_ n: Stride) -> UInt128 {
        if n < 0 {
            return self &- UInt128(n * -1)
        }
        return self &+ UInt128(n)
    }
    /// Returns the distance from the current UInt128 value to the supplied
    /// UInt128 value. This implementation is limited since a signed Int128
    /// data type does not exist, so it has to fall back to an IntMax
    /// representation which lacks half of the storage space when end
    /// is less than the value of self.
    public func distanceTo(_ end: UInt128) -> Stride {
        if end >= self {
            return Stride(end - self)
        }
        return Stride(end) &- Stride(self)
    }
}
// MARK: - IntegerLiteralConvertible
extension UInt128: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Int
    public init(integerLiteral value: UInt128.IntegerLiteralType) {
        self.init(value)
    }
    public init(_builtinIntegerLiteral value: _MaxBuiltinIntegerType) {
        self.init(UInt64(_builtinIntegerLiteral: value))
    }
}
// MARK: - StringLiteralConvertible
extension UInt128: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    public init(stringLiteral value: StringLiteralType) {
        self.init()
        do {
            try self = UInt128.fromUnparsedString(value)
        } catch { return }
    }
    // MARK: UnicodeScalarLiteralConvertible
    public typealias UnicodeScalarLiteralType = String
    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.init(stringLiteral: value)
    }
    // MARK: ExtendedGraphemeClusterLiteralConvertible
    public typealias ExtendedGraphemeClusterLiteralType = String
    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.init(stringLiteral: value)
    }
}
// MARK: - BitwiseOperationsType
extension UInt128: BitwiseOperations {
    public static var allZeros: UInt128 {
        return UInt128(0)
    }
}
/// Performs a bitwise AND operation on 2 UInt128 data types.
public func &(lhs: UInt128, rhs: UInt128) -> UInt128 {
    let upperBits = lhs.value.upperBits & rhs.value.upperBits
    let lowerBits = lhs.value.lowerBits & rhs.value.lowerBits
    return UInt128(upperBits: upperBits, lowerBits: lowerBits)
}
public func &=(lhs: inout UInt128, rhs: UInt128) {
    lhs = lhs & rhs
}
/// Performs a bitwise OR operation on 2 UInt128 data types.
public func |(lhs: UInt128, rhs: UInt128) -> UInt128 {
    let upperBits = lhs.value.upperBits | rhs.value.upperBits
    let lowerBits = lhs.value.lowerBits | rhs.value.lowerBits
    return UInt128(upperBits: upperBits, lowerBits: lowerBits)
}
public func |=(lhs: inout UInt128, rhs: UInt128) {
    lhs = lhs | rhs
}
/// Performs a bitwise XOR operation on 2 UInt128 data types.
public func ^(lhs: UInt128, rhs: UInt128) -> UInt128 {
    let upperBits = lhs.value.upperBits ^ rhs.value.upperBits
    let lowerBits = lhs.value.lowerBits ^ rhs.value.lowerBits
    return UInt128(upperBits: upperBits, lowerBits: lowerBits)
}
public func ^=(lhs: inout UInt128, rhs: UInt128) {
    lhs = lhs ^ rhs
}
/// Performs bit inversion (complement) on the provided UInt128 data type
/// and returns the result.
prefix public func ~(rhs: UInt128) -> UInt128 {
    let upperBits = ~rhs.value.upperBits
    let lowerBits = ~rhs.value.lowerBits
    return UInt128(upperBits: upperBits, lowerBits: lowerBits)
}
/// Shifts `lhs`' bits left by `rhs` bits and returns the result.
public func <<(lhs: UInt128, rhs: UInt128) -> UInt128 {
    if rhs.value.upperBits > 0 || rhs.value.lowerBits > 128 {
        return UInt128(0)
    }
    switch rhs {
    case 0: return lhs // Do nothing shift.
    case 1...63:
        let upperBits = (lhs.value.upperBits << rhs.value.lowerBits) + (lhs.value.lowerBits >> (64 - rhs.value.lowerBits))
        let lowerBits = lhs.value.lowerBits << rhs.value.lowerBits
        return UInt128(upperBits: upperBits, lowerBits: lowerBits)
    case 64:
        // Shift 64 means move lower bits to upper bits.
        return UInt128(upperBits: lhs.value.lowerBits, lowerBits: 0)
    case 65...127:
        let upperBits = lhs.value.lowerBits << UInt64(rhs - 64)
        return UInt128(upperBits: upperBits, lowerBits: 0)
    default: return UInt128(0)
    }
}
public func <<=(lhs: inout UInt128, rhs: UInt128) {
    lhs = lhs << rhs
}
/// Shifts `lhs`' bits right by `rhs` bits and returns the result.
public func >>(lhs: UInt128, rhs: UInt128) -> UInt128 {
    if rhs.value.upperBits > 0 || rhs.value.lowerBits > 128 {
        return UInt128(0)
    }
    switch rhs {
    case 0: return lhs // Do nothing shift.
    case 1...63:
        let upperBits = lhs.value.upperBits >> rhs.value.lowerBits
        let lowerBits = (lhs.value.lowerBits >> rhs.value.lowerBits) + (lhs.value.upperBits << (64 - rhs.value.lowerBits))
        return UInt128(upperBits: upperBits, lowerBits: lowerBits)
    case 64:
        // Shift 64 means move upper bits to lower bits.
        return UInt128(upperBits: 0, lowerBits: lhs.value.upperBits)
    case 65...127:
        let lowerBits = lhs.value.upperBits >> (rhs.value.lowerBits - 64)
        return UInt128(upperBits: 0, lowerBits: lowerBits)
    default: return UInt128(0)
    }
}
public func >>=(lhs: inout UInt128, rhs: UInt128) {
    lhs = lhs >> rhs
}
// MARK: IntegerArithmeticType Conformance
extension UInt128: IntegerArithmetic {
    public func toIntMax() -> IntMax {
        precondition(self.value.lowerBits <= UInt64(IntMax.max) && self.value.upperBits == 0, "Converting `self` to 'IntMax' causes an integer overflow")
        return IntMax(value.lowerBits)
    }
    public static func addWithOverflow(_ lhs: UInt128, _ rhs: UInt128) -> (UInt128, overflow: Bool) {
        var resultOverflow = false
        // Add lower bits and check for overflow.
        let (lowerBits, lowerOverflow) = UInt64.addWithOverflow(
            lhs.value.lowerBits, rhs.value.lowerBits
        )
        // Add upper bits and check for overflow.
        var (upperBits, upperOverflow) = UInt64.addWithOverflow(
            lhs.value.upperBits, rhs.value.upperBits
        )
        // If the lower bits overflowed, we need to add 1 to upper bits.
        if lowerOverflow {
            (upperBits, resultOverflow) = UInt64.addWithOverflow(upperBits, 1)
        }
        return (
            UInt128(upperBits: upperBits, lowerBits: lowerBits),
            upperOverflow || resultOverflow
        )
    }
    public static func subtractWithOverflow(_ lhs: UInt128, _ rhs: UInt128) -> (UInt128, overflow: Bool) {
        var resultOverflow = false
        // Subtract lower bits and check for overflow.
        let (lowerBits, lowerOverflow) = UInt64.subtractWithOverflow(
            lhs.value.lowerBits, rhs.value.lowerBits
        )
        // Subtract upper bits and check for overflow.
        var (upperBits, upperOverflow) = UInt64.subtractWithOverflow(
            lhs.value.upperBits, rhs.value.upperBits
        )
        // If the lower bits overflowed, we need to subtract (borrow) 1 from the upper bits.
        if lowerOverflow {
            (upperBits, resultOverflow) = UInt64.subtractWithOverflow(upperBits, 1)
        }
        return (
            UInt128(upperBits: upperBits, lowerBits: lowerBits),
            upperOverflow || resultOverflow
        )
    }
    public static func divideWithOverflow(_ lhs: UInt128, _ rhs: UInt128) -> (UInt128, overflow: Bool) {
        return (
            (lhs /% rhs).quotient, false
        )
    }
    public static func remainderWithOverflow(_ lhs: UInt128, _ rhs: UInt128) -> (UInt128, overflow: Bool) {
        return (
            (lhs /% rhs).remainder, false
        )
    }
    public static func multiplyWithOverflow(_ lhs: UInt128, _ rhs: UInt128) -> (UInt128, overflow: Bool) {
        // Useful bitmasks to be used later.
        let lower32 = UInt64(UInt32.max)
        let upper32 = ~UInt64(UInt32.max)
        // Decompose lhs into an array of 4, 32 significant bit UInt64s.
        let lhsArray = [
            lhs.value.upperBits >> 32, /*0*/ lhs.value.upperBits & lower32, /*1*/
            lhs.value.lowerBits >> 32, /*2*/ lhs.value.lowerBits & lower32  /*3*/
        ]
        // Decompose rhs into an array of 4, 32 significant bit UInt64s.
        let rhsArray = [
            rhs.value.upperBits >> 32, /*0*/ rhs.value.upperBits & lower32, /*1*/
            rhs.value.lowerBits >> 32, /*2*/ rhs.value.lowerBits & lower32  /*3*/
        ]
        // The future contents of this array will be used to store segment
        // multiplication results.
        var resultArray = [[UInt64]].init(
            repeating: [UInt64].init(
                repeating: 0, count: 4
            ), count: 4
        )
        // Holds overflow status
        var overflow = false
        // Loop through every combination of lhsArray[x] * rhsArray[y]
        for rhsSegment in 0 ..< rhsArray.count {
            for lhsSegment in 0 ..< lhsArray.count {
                let currentValue = lhsArray[lhsSegment] * rhsArray[rhsSegment]
                // Depending upon which segments we're looking at, we'll want to
                // check for overflow conditions and flag them when encountered.
                switch (lhsSegment, rhsSegment) {
                case (0, 0...2): // lhsSegment 1 * rhsSegment 1 to 3 shouldn't have a value.
                    if currentValue > 0 { overflow = true }
                case (0, 3):     // lhsSegment 1 * rhsSegment 4 should only be 32 bits.
                    if currentValue >> 32 > 0 { overflow = true }
                case (1, 0...1): // lhsSegment 2 * rhsSegment 1 or 2 shouldn't have a value.
                    if currentValue > 0 { overflow = true }
                case (1, 2):     // lhsSegment 2 * rhsSegment 3 should only be 32 bits.
                    if currentValue >> 32 > 0 { overflow = true }
                case (2, 0):     // lhsSegment 3 * rhsSegment 1 shouldn't have a value.
                    if currentValue > 0 { overflow = true }
                case (2, 1):     // lhsSegment 3 * rhsSegment 2 should only be 32 bits.
                    if currentValue >> 32 > 0 { overflow = true }
                case (3, 0):     // lhsSegment 4 * rhsSegment 1 should only be 32 bits.
                    if currentValue >> 32 > 0 { overflow = true }
                default: break // only 1 overflow condition still exists which will be checked later.
                }
                // Save the current result into our two-dimensional result array.
                resultArray[lhsSegment][rhsSegment] = currentValue
            }
        }
        // Perform multiplication similar to pen and paper, ignoring calculations
        // that would definitely result in an overflow.
        let fourthBitSegment =  resultArray[3][3] & lower32
        var thirdBitSegment  =  resultArray[2][3] & lower32 +
            resultArray[3][2] & lower32
        // Add overflow from 4th segment.
        thirdBitSegment     += (resultArray[3][3] & upper32) >> 32
        var secondBitSegment =  resultArray[1][3] & lower32 +
            resultArray[2][2] & lower32 +
            resultArray[3][1] & lower32
        // Add overflows from 3rd segment.
        secondBitSegment    += (resultArray[2][3] & upper32) >> 32
        secondBitSegment    += (resultArray[3][2] & upper32) >> 32
        var firstBitSegment  =  resultArray[0][3] & lower32 +
            resultArray[1][2] & lower32 +
            resultArray[2][1] & lower32 +
            resultArray[3][0] & lower32
        // Add overflows from 2nd segment.
        firstBitSegment     += (resultArray[1][3] & upper32) >> 32
        firstBitSegment     += (resultArray[2][2] & upper32) >> 32
        firstBitSegment     += (resultArray[3][1] & upper32) >> 32
        // Slot the bit counts into the appropriate position with multiple adds.
        return (
            UInt128(upperBits: firstBitSegment << 32, lowerBits: 0) &+
                UInt128(upperBits: secondBitSegment, lowerBits: 0) &+
                UInt128(upperBits: thirdBitSegment >> 32, lowerBits: thirdBitSegment << 32) &+
                UInt128(fourthBitSegment),
            overflow || firstBitSegment >> 32 > 0
        )
    }
}
public func +(lhs: UInt128, rhs: UInt128) -> UInt128 {
    precondition(~lhs >= rhs, "Addition overflow!")
    let (result, _) = UInt128.addWithOverflow(lhs, rhs)
    return result
}
public func +=(lhs: inout UInt128, rhs: UInt128) {
    lhs = lhs + rhs
}
prefix public func ++(lhs: inout UInt128) -> UInt128 {
    lhs = lhs + 1
    return lhs
}
postfix public func ++(lhs: inout UInt128) -> UInt128 {
    let result = lhs
    lhs = lhs + 1
    return result
}
public func -(lhs: UInt128, rhs: UInt128) -> UInt128 {
    precondition(lhs >= rhs, "Integer underflow")
    let (result, _) = UInt128.subtractWithOverflow(lhs, rhs)
    return result
}
public func -=(lhs: inout UInt128, rhs: UInt128) {
    lhs = lhs - rhs
}
prefix public func --(lhs: inout UInt128) -> UInt128 {
    lhs = lhs - 1
    return lhs
}
postfix public func --(lhs: inout UInt128) -> UInt128 {
    let result = lhs
    lhs = lhs - 1
    return result
}
public func /(lhs: UInt128, rhs: UInt128) -> UInt128 {
    let (result, _) = UInt128.divideWithOverflow(lhs, rhs)
    return result
}
public func /=(lhs: inout UInt128, rhs: UInt128) {
    lhs = lhs / rhs
}
public func %(lhs: UInt128, rhs: UInt128) -> UInt128 {
    let (result, _) = UInt128.remainderWithOverflow(lhs, rhs)
    return result
}
public func %=(lhs: inout UInt128, rhs: UInt128) {
    lhs = lhs % rhs
}
public func *(lhs: UInt128, rhs: UInt128) -> UInt128 {
    let result = UInt128.multiplyWithOverflow(lhs, rhs)
    precondition(result.overflow == false, "Multiplication overflow!")
    return result.0
}
public func *=(lhs: inout UInt128, rhs: UInt128) {
    lhs = lhs * rhs
}
// MARK: - Division and Modulus Combined Operator
infix operator /% : AssignmentPrecedence
/// Division and Modulus combined. Someone [else's] smart take on the
/// [integer division with remainder] algorithm.
///
/// [else's]:
///     https://github.com/calccrypto/uint128_t
/// [integer division with remainder]:
///     https://en.wikipedia.org/wiki/Division_algorithm#Integer_division_.28unsigned.29_with_remainder
public func /%(dividend: UInt128, divisor: UInt128) -> (quotient: UInt128, remainder: UInt128) {
    // Naughty boy, trying to divide by 0.
    precondition(divisor != 0, "Division by 0")
    // x/1 = x
    if divisor == 1 {
        return (dividend, 0)
    }
    // x/x = 1
    if dividend == divisor {
        return (1, 0)
    }
    // 0/x = 0
    if dividend == 0 {
        return (0, 0)
    }
    // x = y/z, when y < z, x = 0, r: y
    // This would happen with below logic, but doing it now saves a few cycles.
    if dividend < divisor {
        return (0, dividend)
    }
    // Prime the result making the remainder equal the dividend. This will get
    // decremented until no further even divisions can be made.
    var result = (quotient: UInt128(0), remainder: dividend)
    // Initially shift the divisor left by significant bit difference so that quicker
    // division can take place. IE: Discover GCD (Greatest Common Divisor).
    // This value will get shifted right as the algorithm gets closer to the final solution.
    var shiftedDivisor: UInt128 = divisor << (dividend.significantBits - divisor.significantBits)
    // Initially shift 1 by the same amount as shiftedDivisor. Subtracting shiftedDivisor
    // from dividend will be equal to that many subtractions of divisor from dividend.
    var adder: UInt128 = 1 << (dividend.significantBits - divisor.significantBits)
    // Remainder cannot be allowed to get below the divisor.
    while result.remainder >= divisor {
        // If remainder is great than shiftedDivisor we need to loop again as our
        // bit shift is to high for even division.
        if result.remainder >= shiftedDivisor {
            result.remainder -= shiftedDivisor
            result.quotient += adder
        }
        // Protect ourselves from shifting too far too fast.
        if result.remainder.significantBits <= shiftedDivisor.significantBits {
            // Continue to shift down until we've reached our final even division.
            shiftedDivisor >>= 1
            adder >>= 1
        }
    }
    return result
}
// MARK: - Comparable
extension UInt128: Comparable {}
/// Comparable conforming operator that checks if the `lhs` UInt128 is
/// less than the `rhs` UInt128.
public func <(lhs: UInt128, rhs: UInt128) -> Bool {
    if lhs.value.upperBits < rhs.value.upperBits {
        return true
    } else if lhs.value.upperBits == rhs.value.upperBits && lhs.value.lowerBits < rhs.value.lowerBits {
        return true
    }
    return false
}
public func <=(lhs: UInt128, rhs: UInt128) -> Bool {
    if lhs < rhs || lhs == rhs {
        return true
    }
    return false
}
public func >(lhs: UInt128, rhs: UInt128) -> Bool {
    if lhs.value.upperBits > rhs.value.upperBits {
        return true
    } else if lhs.value.upperBits == rhs.value.upperBits && lhs.value.lowerBits > rhs.value.lowerBits {
        return true
    }
    return false
}
public func >=(lhs: UInt128, rhs: UInt128) -> Bool {
    if lhs > rhs || lhs == rhs {
        return true
    }
    return false
}
// MARK: - Equatable
extension UInt128: Equatable {}
/// Equatable conforming operator that checks if the lhs UInt128 is
/// equal to the rhs UInt128.
public func ==(lhs: UInt128, rhs: UInt128) -> Bool {
    if lhs.value.lowerBits == rhs.value.lowerBits && lhs.value.upperBits == rhs.value.upperBits {
        return true
    }
    return false
}
// MARK: - CustomStringConvertible
extension UInt128: CustomStringConvertible {
    public var description: String {
        return self.toString()
    }
}
// MARK: - Extend SignedIntegerType for UInt128
extension SignedInteger {
    public init(_ value: UInt128) {
        self.init(value.toIntMax())
    }
}
// MARK: - Extend UnsignedIntegerType for UInt128
extension UnsignedInteger {
    public init (_ value: UInt128) {
        self.init(value.toUIntMax())
    }
}
// MARK: - Extend String for UInt128
extension String {
    public init(_ value: UInt128) {
        self.init()
        self.append(value.toString())
    }
    public init(_ value: UInt128, radix: Int, uppercase: Bool = true) {
        self.init()
        let string = value.toString(radix: radix, uppercase: uppercase)
        self.append(string)
    }
}
