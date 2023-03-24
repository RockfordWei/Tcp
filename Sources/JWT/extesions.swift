//
//  extensions.swift
//
//
//  Created by Rocky Wei on 2/28/23.
//

import Foundation

public extension UInt32 {
    var gamma0: Self {
        return xorRightShits(2, 13, 22)
    }
    var gamma1: Self {
        return xorRightShits(6, 11, 25)
    }
    var sigma0: Self {
        return xorRightShits(7, 18) ^ (self >> 3)
    }
    var sigma1: Self {
        return xorRightShits(17, 19) ^ (self >> 10)
    }
    internal func xorRightShits(_ shifts: Int ...) -> Self {
        return shifts.map { rotateRight(by: $0) }.reduce(0) { $0 ^ $1 }
    }
    func rotateRight(by shift: Int) -> Self {
        return (self >> shift) | (self << (32 - shift))
    }
    static func choose(x: Self, y: Self, z: Self) -> Self {
        return (x & y) ^ (~x & z)
    }
    static func major(x: Self, y: Self, z: Self) -> Self {
        return (x & y) ^ (x & z) ^ (y & z)
    }
    var bigEndianBytes: [UInt8] {
        return (0..<4).map { UInt8((self >> (24 - 8 * $0)) & 0xFF) }
    }
    static func unpack(from bigEndianData: Data, offset: Int) -> Self {
        return bigEndianData[offset..<offset + 4]
            .enumerated()
            .map { Self($0.element) << (24 - 8 * $0.offset) }
            .reduce(0) { $0 | $1 }
    }
}

public extension UInt64 {
    var gamma0: Self {
        return xorRightShits(28, 34, 39)
    }
    var gamma1: Self {
        return xorRightShits(14, 18, 41)
    }
    var sigma0: Self {
        return xorRightShits(1, 8) ^ (self >> 7)
    }
    var sigma1: Self {
        return xorRightShits(19, 61) ^ (self >> 6)
    }
    internal func xorRightShits(_ shifts: Int ...) -> Self {
        return shifts.map { rotateRight(by: $0) }.reduce(0) { $0 ^ $1 }
    }
    func rotateRight(by shift: Int) -> Self {
        return (self >> shift) | (self << (64 - shift))
    }
    static func choose(x: Self, y: Self, z: Self) -> Self {
        return (x & y) ^ (~x & z)
    }
    static func major(x: Self, y: Self, z: Self) -> Self {
        return (x & y) ^ (x & z) ^ (y & z)
    }
    var bigEndianBytes: [UInt8] {
        return (0..<8).map { UInt8((self >> (56 - 8 * $0)) & 0xFF) }
    }
    static func unpack(from bigEndianData: Data, offset: Int) -> Self {
        return bigEndianData[offset..<offset + 8]
            .enumerated()
            .map { Self($0.element) << (56 - 8 * $0.offset) }
            .reduce(0) { $0 | $1 }
    }
}

public extension Array where Element == UInt8 {
    var hex: String {
        return Data(self).hex
    }
    func digest(algorithm: DigestAlgorithm) throws -> Self {
        let data = Data(self)
        let hash = try data.digest(algorithm: algorithm)
        return hash.map { $0 }
    }
}

public extension Data {
    var hex: String {
        return map { String(format: "%02x", $0) }.joined()
    }
    func digest(algorithm: DigestAlgorithm) throws -> Data {
        switch algorithm {
        case .SHA256:
            return try Data(DigestAlgorithmSHA256(source: self).hash)
        case .SHA512:
            return try Data(DigestAlgorithmSHA512(source: self).hash)
        }
    }
    static func random(size: Int) -> Self {
        let bytes: [UInt8] = (0..<size).map { _ -> UInt8 in
            return UInt8.random(in: 0..<255)
        }
        return Data(bytes)
    }
}
