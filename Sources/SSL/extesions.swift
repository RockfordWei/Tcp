//
//  extensions.swift
//
//
//  Created by Rocky Wei on 2/28/23.
//

import Foundation

public extension UInt32 {
    static func unpack(from bytesInHighEndFirstOrder: [UInt8], offset: Int) -> Self {
        let size = bytesInHighEndFirstOrder.count
        guard offset >= 0 && offset < size else {
            return 0
        }
        var slice = offset + 4 > size ? bytesInHighEndFirstOrder[offset...] : bytesInHighEndFirstOrder[offset ..< (offset + 4)]
        if slice.count < 4 {
            let padding = Data(repeating: 0, count: 4 - slice.count)
            slice.append(contentsOf: padding)
        }
        let n = slice.map { Self($0) }
        return (n[0] << 24) | (n[1] << 16) | (n[2] << 8) | n[3]
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
        let size = MemoryLayout.size(ofValue: self)
        var data = Data(repeating: 0, count: size)
        var this = self
        memcpy(&data, &this, size)
        return data.reversed().map { $0 }
    }
}

public extension UInt64 {
    var bytesInHighEndFirstOrder: [UInt8] {
        let size = MemoryLayout.size(ofValue: self)
        var data = Data(repeating: 0, count: size)
        var this = self
        memcpy(&data, &this, size)
        return data.reversed().map { $0 }
    }
}

public extension Array {
    func rotateRight(by numbers: UInt) -> Self {
        let n = Int(numbers) % count
        let i = index(0, offsetBy: count - n)
        let head = self[..<i]
        var tail = self[i...]
        tail.append(contentsOf: head)
        return Self(tail)
    }
    func chunks(of stride: Int) -> [Self] {
        var array = [Self]()
        var i = 0
        var j = 0
        repeat {
            j = i + stride
            if j > count { j = count }
            let chunk = Self(self[i..<j])
            array.append(chunk)
            i = j
        } while i < count
        return array
    }
}

public extension Array where Element == UInt8 {
    func unpack(from offset: Int = 0) -> UInt32 {
        return UInt32.unpack(from: self, offset: offset)
    }
    func hex() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
    func debug(_ msg: String) {
        #if DEBUG
        print(msg, hex())
        #endif
    }
}

public extension Data {
    var hex: String {
        return map { String(format: "%02x", $0) }.joined()
    }
    var sha256: Data {
        return Data(SHA256(source: self).hash)
    }
}
