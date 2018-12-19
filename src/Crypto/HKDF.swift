//
//  HKDF.swift
//
//  Created by Hanson on 2018/12/7.
//  Copyright © 2018 Nobody. All rights reserved.
//

import Foundation

public class HKDF {

    /// Derive strong key material from the given (weak) input key material.
    ///
    /// - Parameters:
    ///   - algorithm: hash function, defaults to SHA-256
    ///   - ikm: input keying material (IKM)
    ///   - info: (optional) optional context and application specific information
    ///   - salt: (optional) ikm, a non-secret random value
    ///   - count: desired output key size
    /// - Returns: output keying material (OKM)

    public static func deriveKey(ikm: Data, salt: Data, info: Data, algorithm: HashAlgorithm = .SHA256, count: Int) -> Data {
        // extract
        let prk = HMAC.final(value: ikm, algorithm: algorithm, key: salt)

        // expand
        let iterations = Int(ceil(Double(count) / Double(algorithm.digestLength)))

        var mixin = [UInt8]()
        var result = [UInt8]()

        for iteration in 1...iterations {
            mixin = HMAC(algorithm: algorithm, key: prk)
                .update(byteArray: mixin)
                .update(data: info)
                .update(byteArray: [UInt8(iteration)])
                .final().map { $0 }

            result.append(contentsOf: mixin)
        }

        return Data(bytes: result[0..<count])
    }

}
