//
//  BinaryDataScanner.swift
//  Murphy
//
//  Created by Dave Peck on 7/20/14.
//  Copyright (c) 2014 Dave Peck. All rights reserved.
//

import Foundation

/*
Toying with tools to help read binary formats.

I've seen lots of approaches in swift that create
an intermediate object per-read (usually another NSData)
but even if these are lightweight under the hood,
it seems like overkill. Plus this taught me about <()> aka <Void>

And it would be nice to have an extension to
NSFileHandle too that does much the same.
*/

protocol BinaryReadable {
    var littleEndian: Self { get }
    var bigEndian: Self { get }
}

extension UInt8: BinaryReadable {
    var littleEndian: UInt8 { return self }
    var bigEndian: UInt8 { return self }
}

extension UInt16: BinaryReadable {}

extension UInt32: BinaryReadable {}

extension UInt64: BinaryReadable {}

class BinaryDataScanner {
    let data: NSData
    let littleEndian: Bool
//    let encoding: NSStringEncoding

    var current: UnsafePointer<Void>
    var remaining: Int
    var position: Int {
        get {
            return data.length - remaining
        }
    }

    init(data: NSData, littleEndian: Bool) {
        self.data = data
        self.littleEndian = littleEndian
//        self.encoding = encoding

        self.current = self.data.bytes
        self.remaining = self.data.length
    }

    func read<T: BinaryReadable>() -> T? {
        if remaining < sizeof(T) {
            return nil
        }

        let tCurrent = UnsafePointer<T>(current)
        let v = tCurrent.memory
        current = UnsafePointer<Void>(tCurrent.successor())
        remaining -= sizeof(T)
        return littleEndian ? v.littleEndian : v.bigEndian
    }

    // swiftlint:disable variable_name
    func skipTo(n: Int) {
        remaining = data.length - n
        current = data.bytes.advancedBy(n)
    }

    func advanceBy(n: Int) {
        remaining -= n
        current = current.advancedBy(n)
    }

    /* convenience read funcs */

    func readByte() -> UInt8? {
        return read()
    }

    func read16() -> UInt16? {
        return read()
    }

    func read32() -> UInt32? {
        return read()
    }

    func read64() -> UInt64? {
        return read()
    }
}
