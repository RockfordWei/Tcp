//
//  extensions.swift
//
//
//  Created by Rocky Wei on 2/28/23.
//

import Foundation

// swiftlint:disable operator_usage_whitespace
public extension UInt32 {
    static func unpack(from bytesInHighEndFirstOrder: [UInt8], offset: Int) -> Self {
        let a = Self(bytesInHighEndFirstOrder[offset    ]) << 24
        let b = Self(bytesInHighEndFirstOrder[offset + 1]) << 16
        let c = Self(bytesInHighEndFirstOrder[offset + 2]) << 8
        let d = Self(bytesInHighEndFirstOrder[offset + 3])
        return a | b | c | d
    }
    var sigma0: Self {
        let x = rotateRight(by: 7)
        let y = rotateRight(by: 18)
        let z = (self >> 3)
        return x ^ y ^ z
    }
    var sigma1: Self {
        let x = rotateRight(by: 17)
        let y = rotateRight(by: 19)
        let z = self >> 10
        return x ^ y ^ z
    }
    var gamma0: Self {
        let x = rotateRight(by: 2)
        let y = rotateRight(by: 13)
        let z = rotateRight(by: 22)
        return x ^ y ^ z
    }
    var gamma1: Self {
        let x = rotateRight(by: 6)
        let y = rotateRight(by: 11)
        let z = rotateRight(by: 25)
        return x ^ y ^ z
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
    var bytesInHighEndFirstOrder: [UInt8] {
        let a = UInt8((self & 0xFF000000) >> 24)
        let b = UInt8((self & 0x00FF0000) >> 16)
        let c = UInt8((self & 0x0000FF00) >>  8)
        let d = UInt8( self & 0x000000FF)
        return [a, b, c, d]
    }
}

// swiftlint:disable operator_usage_whitespace
public extension UInt64 {
    var bytesInHighEndFirstOrder: [UInt8] {
        let a = UInt8((self & 0xFF00000000000000) >> 56)
        let b = UInt8((self & 0x00FF000000000000) >> 48)
        let c = UInt8((self & 0x0000FF0000000000) >> 40)
        let d = UInt8((self & 0x000000FF00000000) >> 32)
        let e = UInt8((self & 0x00000000FF000000) >> 24)
        let f = UInt8((self & 0x0000000000FF0000) >> 16)
        let g = UInt8((self & 0x000000000000FF00) >>  8)
        let h = UInt8( self & 0x00000000000000FF)
        return [a, b, c, d, e, f, g, h]
    }
}

public extension Array where Element == UInt8 {
    func unpack(from offset: Int = 0) -> UInt32 {
        return UInt32.unpack(from: self, offset: offset)
    }
    func hex() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

public extension Data {
    var hex: String {
        return map { $0 }.hex()
    }
    var sha256: Data {
        return Data(SHA256(source: self).hash)
    }
}
