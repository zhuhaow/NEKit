//
// UInt128.swift
//
// An implementation of a 128-bit unsigned integer data type not
// relying on any outside libraries apart from Swift's standard
// library. It also seeks to implement the entirety of the
// UnsignedInteger protocol as well as standard functions supported
// by Swift's native unsigned integer types.
//
// Copyright 2017 Joel Gerber
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

// MARK: Error Type

/// An `ErrorType` for `UInt128` data types. It includes cases
/// for errors that can occur during string
/// conversion.
public enum UInt128Errors : Error {
    /// Input cannot be converted to a UInt128 value.
    case invalidString
}

// MARK: - Data Type

/// A 128-bit unsigned integer value type.
/// Storage is based upon a tuple of 2, 64-bit, unsigned integers.
public struct UInt128 {
    // MARK: Instance Properties
    
    /// Internal value is presented as a tuple of 2 64-bit
    /// unsigned integers.
    internal var value: (upperBits: UInt64, lowerBits: UInt64)
    
    /// Counts up the significant bits in stored data.
    public var significantBits: UInt128 {
        var significantBits: UInt128 = 0
        var bitsToWalk: UInt64 = 0 // The bits to crawl in loop.
        
        // When upperBits > 0, lowerBits are all significant.
        if self.value.upperBits > 0 {
            bitsToWalk = self.value.upperBits
            significantBits = 64
        } else if self.value.lowerBits > 0 {
            bitsToWalk = self.value.lowerBits
        }
        
        // Walk significant bits by shifting right until all bits are equal to 0.
        while bitsToWalk > 0 {
            bitsToWalk >>= 1
            significantBits += 1
        }
        
        return significantBits
    }
    
    /// Undocumented private variable required for passing this type
    /// to a BinaryFloatingPoint type. See FloatingPoint.swift.gyb in
    /// the Swift stdlib/public/core directory.
    internal var signBitIndex: Int {
        return 127 - leadingZeroBitCount
    }
    
    // MARK: Initializers
    
    /// Designated initializer for the UInt128 type.
    public init(upperBits: UInt64, lowerBits: UInt64) {
        value.upperBits = upperBits
        value.lowerBits = lowerBits
    }
    
    public init() {
        self.init(upperBits: 0, lowerBits: 0)
    }
    
    public init(_ source: UInt128) {
        self.init(upperBits: source.value.upperBits,
                  lowerBits: source.value.lowerBits)
    }
    
    /// Initialize a UInt128 value from a string.
    ///
    /// - parameter source: the string that will be converted into a
    ///   UInt128 value. Defaults to being analyzed as a base10 number,
    ///   but can be prefixed with `0b` for base2, `0o` for base8
    ///   or `0x` for base16.
    public init(_ source: String) throws {
        guard let result = UInt128._valueFromString(source) else {
            throw UInt128Errors.invalidString
        }
        self = result
    }
}

// MARK: - FixedWidthInteger Conformance

extension UInt128 : FixedWidthInteger {
    // MARK: Instance Properties
    
    public var nonzeroBitCount: Int {
        var nonZeroCount = 0
        var shiftWidth = 0
        
        while shiftWidth < 128 {
            let shiftedSelf = self &>> shiftWidth
            let currentBit = shiftedSelf & 1
            if currentBit == 1 {
                nonZeroCount += 1
            }
            shiftWidth += 1
        }
        
        return nonZeroCount
    }
    
    public var leadingZeroBitCount: Int {
        var zeroCount = 0
        var shiftWidth = 127
        
        while shiftWidth >= 0 {
            let currentBit = self &>> shiftWidth
            guard currentBit == 0 else { break }
            zeroCount += 1
            shiftWidth -= 1
        }
        
        return zeroCount
    }
    
    /// Returns the big-endian representation of the integer, changing the byte order if necessary.
    public var bigEndian: UInt128 {
        #if arch(i386) || arch(x86_64) || arch(arm) || arch(arm64)
            return self.byteSwapped
        #else
            return self
        #endif
    }
    
    /// Returns the little-endian representation of the integer, changing the byte order if necessary.
    public var littleEndian: UInt128 {
        #if arch(i386) || arch(x86_64) || arch(arm) || arch(arm64)
            return self
        #else
            return self.byteSwapped
        #endif
    }
    
    /// Returns the current integer with the byte order swapped.
    public var byteSwapped: UInt128 {
        return UInt128(upperBits: self.value.lowerBits.byteSwapped, lowerBits: self.value.upperBits.byteSwapped)
    }
    
    // MARK: Initializers
    
    /// Creates a UInt128 from a given value, with the input's value
    /// truncated to a size no larger than what UInt128 can handle.
    /// Since the input is constrained to an UInt, no truncation needs
    /// to occur, as a UInt is currently 64 bits at the maximum.
    public init(_truncatingBits bits: UInt) {
        self.init(upperBits: 0, lowerBits: UInt64(bits))
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
    
    public func addingReportingOverflow(_ rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        var resultOverflow = false
        let (lowerBits, lowerOverflow) = self.value.lowerBits.addingReportingOverflow(rhs.value.lowerBits)
        var (upperBits, upperOverflow) = self.value.upperBits.addingReportingOverflow(rhs.value.upperBits)
        
        // If the lower bits overflowed, we need to add 1 to upper bits.
        if lowerOverflow {
            (upperBits, resultOverflow) = upperBits.addingReportingOverflow(1)
        }
        
        return (partialValue: UInt128(upperBits: upperBits, lowerBits: lowerBits),
                overflow: upperOverflow || resultOverflow)
    }
    
    public func subtractingReportingOverflow(_ rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        var resultOverflow = false
        let (lowerBits, lowerOverflow) = self.value.lowerBits.subtractingReportingOverflow(rhs.value.lowerBits)
        var (upperBits, upperOverflow) = self.value.upperBits.subtractingReportingOverflow(rhs.value.upperBits)
        
        // If the lower bits overflowed, we need to subtract (borrow) 1 from the upper bits.
        if lowerOverflow {
            (upperBits, resultOverflow) = upperBits.subtractingReportingOverflow(1)
        }
        
        return (partialValue: UInt128(upperBits: upperBits, lowerBits: lowerBits),
                overflow: upperOverflow || resultOverflow)
    }
    
    public func multipliedReportingOverflow(by rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        let multiplicationResult = self.multipliedFullWidth(by: rhs)
        let overflowEncountered = multiplicationResult.high > 0
        
        return (partialValue: multiplicationResult.low,
                overflow: overflowEncountered)
    }
    
    public func multipliedFullWidth(by other: UInt128) -> (high: UInt128, low: UInt128.Magnitude) {
        // Bit mask that facilitates masking the lower 32 bits of a 64 bit UInt.
        let lower32 = UInt64(UInt32.max)
        
        // Decompose lhs into an array of 4, 32 significant bit UInt64s.
        let lhsArray = [
            self.value.upperBits >> 32, /*0*/ self.value.upperBits & lower32, /*1*/
            self.value.lowerBits >> 32, /*2*/ self.value.lowerBits & lower32  /*3*/
        ]
        
        // Decompose rhs into an array of 4, 32 significant bit UInt64s.
        let rhsArray = [
            other.value.upperBits >> 32, /*0*/ other.value.upperBits & lower32, /*1*/
            other.value.lowerBits >> 32, /*2*/ other.value.lowerBits & lower32  /*3*/
        ]
        
        // The future contents of this array will be used to store segment
        // multiplication results.
        var resultArray = [[UInt64]].init(
            repeating: [UInt64].init(repeating: 0, count: 4), count: 4
        )
        
        // Loop through every combination of lhsArray[x] * rhsArray[y]
        for rhsSegment in 0 ..< rhsArray.count {
            for lhsSegment in 0 ..< lhsArray.count {
                let currentValue = lhsArray[lhsSegment] * rhsArray[rhsSegment]
                resultArray[lhsSegment][rhsSegment] = currentValue
            }
        }
        
        // Perform multiplication similar to pen and paper in 64bit, 32bit masked increments.
        let bitSegment8 = resultArray[3][3] & lower32
        let bitSegment7 = UInt128._variadicAdditionWithOverflowCount(
            resultArray[2][3] & lower32,
            resultArray[3][2] & lower32,
            resultArray[3][3] >> 32) // overflow from bitSegment8
        let bitSegment6 = UInt128._variadicAdditionWithOverflowCount(
            resultArray[1][3] & lower32,
            resultArray[2][2] & lower32,
            resultArray[3][1] & lower32,
            resultArray[2][3] >> 32, // overflow from bitSegment7
            resultArray[3][2] >> 32, // overflow from bitSegment7
            bitSegment7.overflowCount)
        let bitSegment5 = UInt128._variadicAdditionWithOverflowCount(
            resultArray[0][3] & lower32,
            resultArray[1][2] & lower32,
            resultArray[2][1] & lower32,
            resultArray[3][0] & lower32,
            resultArray[1][3] >> 32, // overflow from bitSegment6
            resultArray[2][2] >> 32, // overflow from bitSegment6
            resultArray[3][1] >> 32, // overflow from bitSegment6
            bitSegment6.overflowCount)
        let bitSegment4 = UInt128._variadicAdditionWithOverflowCount(
            resultArray[0][2] & lower32,
            resultArray[1][1] & lower32,
            resultArray[2][0] & lower32,
            resultArray[0][3] >> 32, // overflow from bitSegment5
            resultArray[1][2] >> 32, // overflow from bitSegment5
            resultArray[2][1] >> 32, // overflow from bitSegment5
            resultArray[3][0] >> 32, // overflow from bitSegment5
            bitSegment5.overflowCount)
        let bitSegment3 = UInt128._variadicAdditionWithOverflowCount(
            resultArray[0][1] & lower32,
            resultArray[1][0] & lower32,
            resultArray[0][2] >> 32, // overflow from bitSegment4
            resultArray[1][1] >> 32, // overflow from bitSegment4
            resultArray[2][0] >> 32, // overflow from bitSegment4
            bitSegment4.overflowCount)
        let bitSegment1 = UInt128._variadicAdditionWithOverflowCount(
            resultArray[0][0],
            resultArray[0][1] >> 32, // overflow from bitSegment3
            resultArray[1][0] >> 32, // overflow from bitSegment3
            bitSegment3.overflowCount)
        
        // Shift and merge the results into 64 bit groups, adding in overflows as we go.
        let lowerLowerBits = UInt128._variadicAdditionWithOverflowCount(
            bitSegment8,
            bitSegment7.truncatedValue << 32)
        let upperLowerBits = UInt128._variadicAdditionWithOverflowCount(
            bitSegment7.truncatedValue >> 32,
            bitSegment6.truncatedValue,
            bitSegment5.truncatedValue << 32,
            lowerLowerBits.overflowCount)
        let lowerUpperBits = UInt128._variadicAdditionWithOverflowCount(
            bitSegment5.truncatedValue >> 32,
            bitSegment4.truncatedValue,
            bitSegment3.truncatedValue << 32,
            upperLowerBits.overflowCount)
        let upperUpperBits = UInt128._variadicAdditionWithOverflowCount(
            bitSegment3.truncatedValue >> 32,
            bitSegment1.truncatedValue,
            lowerUpperBits.overflowCount)
        
        // Bring the 64bit unsigned integer results together into a high and low 128bit unsigned integer result.
        return (high: UInt128(upperBits: upperUpperBits.truncatedValue, lowerBits: lowerUpperBits.truncatedValue),
                low: UInt128(upperBits: upperLowerBits.truncatedValue, lowerBits: lowerLowerBits.truncatedValue))
    }
    
    /// Takes a variable amount of 64bit Unsigned Integers and adds them together,
    /// tracking the total amount of overflows that occurred during addition.
    ///
    /// - Parameter addends:
    ///      Variably sized list of UInt64 values.
    /// - Returns:
    ///      A tuple containing the truncated result and a count of the total
    ///      amount of overflows that occurred during addition.
    private static func _variadicAdditionWithOverflowCount(_ addends: UInt64...) -> (truncatedValue: UInt64, overflowCount: UInt64) {
        var sum: UInt64 = 0
        var overflowCount: UInt64 = 0
        
        addends.forEach { addend in
            let interimSum = sum.addingReportingOverflow(addend)
            if interimSum.overflow {
                overflowCount += 1
            }
            sum = interimSum.partialValue
        }
        
        return (truncatedValue: sum, overflowCount: overflowCount)
    }
    
    public func dividedReportingOverflow(by rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        guard rhs != 0 else {
            return (self, true)
        }
        
        let quotient = self.quotientAndRemainder(dividingBy: rhs).quotient
        return (quotient, false)
    }
    
    public func dividingFullWidth(_ dividend: (high: UInt128, low: UInt128)) -> (quotient: UInt128, remainder: UInt128) {
        return self._quotientAndRemainderFullWidth(dividingBy: dividend)
    }
    
    public func remainderReportingOverflow(dividingBy rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        guard rhs != 0 else {
            return (self, true)
        }
        
        let remainder = self.quotientAndRemainder(dividingBy: rhs).remainder
        return (remainder, false)
    }
    
    public func quotientAndRemainder(dividingBy rhs: UInt128) -> (quotient: UInt128, remainder: UInt128) {
        return rhs._quotientAndRemainderFullWidth(dividingBy: (high: 0, low: self))
    }
    
    /// Provides the quotient and remainder when dividing the provided value by self.
    internal func _quotientAndRemainderFullWidth(dividingBy dividend: (high: UInt128, low: UInt128)) -> (quotient: UInt128, remainder: UInt128) {
        let divisor = self
        let numeratorBitsToWalk: UInt128
        
        if dividend.high > 0 {
            numeratorBitsToWalk = dividend.high.significantBits + 128 - 1
        } else if dividend.low == 0 {
            return (0, 0)
        } else {
            numeratorBitsToWalk = dividend.low.significantBits - 1
        }
        
        // The below algorithm was adapted from:
        // https://en.wikipedia.org/wiki/Division_algorithm#Integer_division_.28unsigned.29_with_remainder
        
        precondition(self != 0, "Division by 0")
        
        var quotient = UInt128.min
        var remainder = UInt128.min
        
        for numeratorShiftWidth in (0...numeratorBitsToWalk).reversed() {
            remainder <<= 1
            remainder |= UInt128._bitFromDoubleWidth(at: numeratorShiftWidth, for: dividend)
            
            if remainder >= divisor {
                remainder -= divisor
                quotient |= 1 << numeratorShiftWidth
            }
        }
        
        return (quotient, remainder)
    }
    
    /// Returns the bit stored at the given position for the provided double width UInt128 input.
    ///
    /// - parameter at: position to grab bit value from.
    /// - parameter for: the double width UInt128 data value to grab the
    ///   bit from.
    /// - returns: single bit stored in a UInt128 value.
    internal static func _bitFromDoubleWidth(at bitPosition: UInt128, for input: (high: UInt128, low: UInt128)) -> UInt128 {
        switch bitPosition {
        case 0:
            return input.low & 1
        case 1...127:
            return input.low >> bitPosition & 1
        case 128:
            return input.high & 1
        default:
            return input.high >> (bitPosition - 128) & 1
        }
    }
}

// MARK: - BinaryInteger Conformance

extension UInt128 : BinaryInteger {
    // MARK: Instance Properties
    
    public static var bitWidth : Int { return 128 }
    
    
    // MARK: Instance Methods
    
    public var words: [UInt] {
        guard self != UInt128.min else {
            return []
        }
        
        var words: [UInt] = []
        
        for currentWord in 0 ... self.bitWidth / UInt.bitWidth {
            let shiftAmount: UInt64 = UInt64(UInt.bitWidth) * UInt64(currentWord)
            let mask = UInt64(UInt.max)
            var shifted = self
            
            if shiftAmount > 0 {
                shifted &>>= UInt128(upperBits: 0, lowerBits: shiftAmount)
            }
            
            let masked: UInt128 = shifted & UInt128(upperBits: 0, lowerBits: mask)
            
            words.append(UInt(masked.value.lowerBits))
        }
        return words
    }
    
    public var trailingZeroBitCount: Int {
        let mask: UInt128 = 1
        var bitsToWalk = self
        
        for currentPosition in 0...128 {
            if bitsToWalk & mask == 1 {
                return currentPosition
            }
            bitsToWalk >>= 1
        }
        
        return 128
    }
    
    // MARK: Initializers
    
    public init?<T : BinaryFloatingPoint>(exactly source: T) {
        if source.isZero {
            self = UInt128()
        }
        else if source.exponent < 0 || source.rounded() != source {
            return nil
        }
        else {
            self = UInt128(UInt64(source))
        }
    }
    
    public init<T : BinaryFloatingPoint>(_ source: T) {
        self.init(UInt64(source))
    }
    
    // MARK: Type Methods
    
    public static func /(_ lhs: UInt128, _ rhs: UInt128) -> UInt128 {
        let result = lhs.dividedReportingOverflow(by: rhs)
        
        return result.partialValue
    }
    
    public static func /=(_ lhs: inout UInt128, _ rhs: UInt128) {
        lhs = lhs / rhs
    }
    
    public static func %(_ lhs: UInt128, _ rhs: UInt128) -> UInt128 {
        let result = lhs.remainderReportingOverflow(dividingBy: rhs)
        
        return result.partialValue
    }
    
    public static func %=(_ lhs: inout UInt128, _ rhs: UInt128) {
        lhs = lhs % rhs
    }
    
    /// Performs a bitwise AND operation on 2 UInt128 data types.
    public static func &=(_ lhs: inout UInt128, _ rhs: UInt128) {
        let upperBits = lhs.value.upperBits & rhs.value.upperBits
        let lowerBits = lhs.value.lowerBits & rhs.value.lowerBits
        
        lhs = UInt128(upperBits: upperBits, lowerBits: lowerBits)
    }
    
    /// Performs a bitwise OR operation on 2 UInt128 data types.
    public static func |=(_ lhs: inout UInt128, _ rhs: UInt128) {
        let upperBits = lhs.value.upperBits | rhs.value.upperBits
        let lowerBits = lhs.value.lowerBits | rhs.value.lowerBits
        
        lhs = UInt128(upperBits: upperBits, lowerBits: lowerBits)
    }
    
    /// Performs a bitwise XOR operation on 2 UInt128 data types.
    public static func ^=(_ lhs: inout UInt128, _ rhs: UInt128) {
        let upperBits = lhs.value.upperBits ^ rhs.value.upperBits
        let lowerBits = lhs.value.lowerBits ^ rhs.value.lowerBits
        
        lhs = UInt128(upperBits: upperBits, lowerBits: lowerBits)
    }
    
    /// Perform a masked right SHIFT operation self.
    ///
    /// The masking operation will mask `rhs` against the highest
    /// shift value that will not cause an overflowing shift before
    /// performing the shift. IE: `rhs = 128` will become `rhs = 0`
    /// and `rhs = 129` will become `rhs = 1`.
    public static func &>>=(_ lhs: inout UInt128, _ rhs: UInt128) {
        let shiftWidth = rhs.value.lowerBits & 127
        
        switch shiftWidth {
        case 0: return // Do nothing shift.
        case 1...63:
            let upperBits = lhs.value.upperBits >> shiftWidth
            let lowerBits = (lhs.value.lowerBits >> shiftWidth) + (lhs.value.upperBits << (64 - shiftWidth))
            lhs = UInt128(upperBits: upperBits, lowerBits: lowerBits)
        case 64:
            // Shift 64 means move upper bits to lower bits.
            lhs = UInt128(upperBits: 0, lowerBits: lhs.value.upperBits)
        default:
            let lowerBits = lhs.value.upperBits >> (shiftWidth - 64)
            lhs = UInt128(upperBits: 0, lowerBits: lowerBits)
        }
    }
    
    /// Perform a masked left SHIFT operation on self.
    ///
    /// The masking operation will mask `rhs` against the highest
    /// shift value that will not cause an overflowing shift before
    /// performing the shift. IE: `rhs = 128` will become `rhs = 0`
    /// and `rhs = 129` will become `rhs = 1`.
    public static func &<<=(_ lhs: inout UInt128, _ rhs: UInt128) {
        let shiftWidth = rhs.value.lowerBits & 127
        
        switch shiftWidth {
        case 0: return // Do nothing shift.
        case 1...63:
            let upperBits = (lhs.value.upperBits << shiftWidth) + (lhs.value.lowerBits >> (64 - shiftWidth))
            let lowerBits = lhs.value.lowerBits << shiftWidth
            lhs = UInt128(upperBits: upperBits, lowerBits: lowerBits)
        case 64:
            // Shift 64 means move lower bits to upper bits.
            lhs = UInt128(upperBits: lhs.value.lowerBits, lowerBits: 0)
        default:
            let upperBits = lhs.value.lowerBits << (shiftWidth - 64)
            lhs = UInt128(upperBits: upperBits, lowerBits: 0)
        }
    }
}

// MARK: - UnsignedInteger Conformance

extension UInt128 : UnsignedInteger {}

// MARK: - Hashable Conformance

extension UInt128 : Hashable {
    public var hashValue: Int {
        return self.value.lowerBits.hashValue ^ self.value.upperBits.hashValue
    }
}

// MARK: - Numeric Conformance

extension UInt128 : Numeric {
    public static func +(_ lhs: UInt128, _ rhs: UInt128) -> UInt128 {
        precondition(~lhs >= rhs, "Addition overflow!")
        let result = lhs.addingReportingOverflow(rhs)
        return result.partialValue
    }
    public static func +=(_ lhs: inout UInt128, _ rhs: UInt128) {
        lhs = lhs + rhs
    }
    public static func -(_ lhs: UInt128, _ rhs: UInt128) -> UInt128 {
        precondition(lhs >= rhs, "Integer underflow")
        let result = lhs.subtractingReportingOverflow(rhs)
        return result.partialValue
    }
    public static func -=(_ lhs: inout UInt128, _ rhs: UInt128) {
        lhs = lhs - rhs
    }
    public static func *(_ lhs: UInt128, _ rhs: UInt128) -> UInt128 {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        precondition(!result.overflow, "Multiplication overflow!")
        return result.partialValue
    }
    public static func *=(_ lhs: inout UInt128, _ rhs: UInt128) {
        lhs = lhs * rhs
    }
}

// MARK: - Equatable Conformance

extension UInt128 : Equatable {
    /// Checks if the `lhs` is equal to the `rhs`.
    public static func ==(lhs: UInt128, rhs: UInt128) -> Bool {
        if lhs.value.lowerBits == rhs.value.lowerBits && lhs.value.upperBits == rhs.value.upperBits {
            return true
        }
        return false
    }
}

// MARK: - ExpressibleByIntegerLiteral Conformance

extension UInt128 : ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self.init(upperBits: 0, lowerBits: UInt64(value))
    }
}

// MARK: - CustomStringConvertible Conformance

extension UInt128 : CustomStringConvertible {
    // MARK: Instance Properties
    
    public var description: String {
        return self._valueToString()
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
    internal func _valueToString(radix: Int = 10, uppercase: Bool = true) -> String {
        precondition(radix > 1 && radix < 37, "radix must be within the range of 2-36.")
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
        let characterPool = (uppercase) ? "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" : "0123456789abcdefghijklmnopqrstuvwxyz"
        // Go through internal value until every base position is string(ed).
        repeat {
            divmodResult = divmodResult.quotient.quotientAndRemainder(dividingBy: UInt128(radix))
            let index = characterPool.index(characterPool.startIndex, offsetBy: Int(divmodResult.remainder))
            result.insert(characterPool[index], at: result.startIndex)
        } while divmodResult.quotient > 0
        return result
    }
}

// MARK: - CustomDebugStringConvertible Conformance

extension UInt128 : CustomDebugStringConvertible {
    public var debugDescription: String {
        return self.description
    }
}

// MARK: - Comparable Conformance

extension UInt128 : Comparable {
    public static func <(lhs: UInt128, rhs: UInt128) -> Bool {
        if lhs.value.upperBits < rhs.value.upperBits {
            return true
        } else if lhs.value.upperBits == rhs.value.upperBits && lhs.value.lowerBits < rhs.value.lowerBits {
            return true
        }
        return false
    }
}

// MARK: - ExpressibleByStringLiteral Conformance

extension UInt128 : ExpressibleByStringLiteral {
    // MARK: Initializers
    
    public init(stringLiteral value: StringLiteralType) {
        self.init()
        
        if let result = UInt128._valueFromString(value) {
            self = result
        }
    }
    
    // MARK: Type Methods
    
    internal static func _valueFromString(_ value: String) -> UInt128? {
        let radix = UInt128._determineRadixFromString(value)
        let inputString = radix == 10 ? value : String(value.dropFirst(2))
        
        return UInt128(inputString, radix: radix)
    }
    
    internal static func _determineRadixFromString(_ string: String) -> Int {
        let radix: Int
        
        if string.hasPrefix("0b") { radix = 2 }
        else if string.hasPrefix("0o") { radix = 8 }
        else if string.hasPrefix("0x") { radix = 16 }
        else { radix = 10 }
        
        return radix
    }
}

// MARK: - Deprecated API

extension UInt128 {
    /// Initialize a UInt128 value from a string.
    ///
    /// - parameter source: the string that will be converted into a
    ///   UInt128 value. Defaults to being analyzed as a base10 number,
    ///   but can be prefixed with `0b` for base2, `0o` for base8
    ///   or `0x` for base16.
    @available(swift, deprecated: 3.2, renamed: "init(_:)")
    public static func fromUnparsedString(_ source: String) throws -> UInt128 {
        return try UInt128.init(source)
    }
}

// MARK: - BinaryFloatingPoint Interworking

extension BinaryFloatingPoint {
    public init(_ value: UInt128) {
        precondition(value.value.upperBits == 0, "Value is too large to fit into a BinaryFloatingPoint until a 128bit BinaryFloatingPoint type is defined.")
        self.init(value.value.lowerBits)
    }
    
    public init?(exactly value: UInt128) {
        if value.value.upperBits > 0 {
            return nil
        }
        self = Self(value.value.lowerBits)
    }
}

// MARK: - String Interworking

extension String {
    /// Creates a string representing the given value in base 10, or some other
    /// specified base.
    ///
    /// - Parameters:
    ///   - value: The UInt128 value to convert to a string.
    ///   - radix: The base to use for the string representation. `radix` must be
    ///     at least 2 and at most 36. The default is 10.
    ///   - uppercase: Pass `true` to use uppercase letters to represent numerals
    ///     or `false` to use lowercase letters. The default is `false`.
    public init(_ value: UInt128, radix: Int = 10, uppercase: Bool = false) {
        self = value._valueToString(radix: radix, uppercase: uppercase)
    }
}
