//
//  SHA-256.swift
//
//
//  Created by Rocky Wei on 2023-03-01.
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif
import Foundation

struct DigestAlgorithmSHA256 {
    internal static let ending: [UInt8] = [0x80]
    public let hash: [UInt8]
    public init(source: Data) {
        var message = source
        let length = UInt64(message.count * 8)
        var tailSize = SHA256Round.chunkSize - 8
        let remain = (message.count + 1) % SHA256Round.chunkSize
        if remain != tailSize {
            tailSize -= remain
            if tailSize < 0 {
                tailSize += SHA256Round.chunkSize
            }
        }
        let padding = Self.ending + [UInt8](repeating: 0, count: tailSize) + length.bigEndianBytes
        message.append(contentsOf: padding)
        
        let blocks = message.count / SHA256Round.chunkSize
        let round = SHA256Round()
        for index in 0..<blocks {
            let start = index * SHA256Round.chunkSize
            let end = start + SHA256Round.chunkSize
            let block = Data(message[start..<end])
            round.calculate(block: block)
        }
        hash = round.hashValue
    }
    public init(streamReaderFileNumber: Int32) {
        var totalBytes = 0
        var index = 0
        var inProgress = true
        let round = SHA256Round()
        var lastBlock: [UInt8] = []
        while inProgress {
            var block = [UInt8](repeating: 0, count: SHA256Round.chunkSize)
            let size = block.withUnsafeMutableBytes { pointer -> Int in
                #if os(Linux)
                return Glibc.read(streamReaderFileNumber, pointer.baseAddress, SHA256Round.chunkSize)
                #else
                return Darwin.read(streamReaderFileNumber, pointer.baseAddress, SHA256Round.chunkSize)
                #endif
            }
            if size >= 0 {
                totalBytes += size
            }
            let length = UInt64(totalBytes * 8)
            if size < (SHA256Round.chunkSize - 9) {
                block = [UInt8](block[0..<size]) + Self.ending + [UInt8](repeating: 0, count: SHA256Round.chunkSize - size - 9) + length.bigEndianBytes
                inProgress = false
            } else if size < SHA256Round.chunkSize {
                block[size] = Self.ending[0]
                lastBlock = [UInt8](repeating: 0, count: SHA256Round.chunkSize - 8) + length.bigEndianBytes
                inProgress = false
            } else {
                inProgress = true
            }
            round.calculate(block: Data(block))
            index += 1
        }
        if lastBlock.count == SHA256Round.chunkSize {
            round.calculate(block: Data(lastBlock))
        }
        #if os(Linux)
        Glibc.close(streamReaderFileNumber)
        #else
        Darwin.close(streamReaderFileNumber)
        #endif
        hash = round.hashValue
    }
}

fileprivate class SHA256Round {
    static let chunkSize = 64
    /// first 32 bits of the fractional parts of the cube roots of the first 64 primes 2..311
    static let K: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]
    /// first 32 bits of the fractional parts of the square roots of the first 8 primes 2..19
    private var H: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]
    var hashValue: [UInt8] {
        return H.flatMap { $0.bigEndianBytes }
    }
    func calculate(block: Data) {
        assert(block.count == Self.chunkSize)
        var W = [UInt32](repeating: 0, count: Self.chunkSize)
        for i in 0..<Self.chunkSize {
            W[i] = i < 16 ? UInt32.unpack(from: block, offset: i * 4)
                : W[i - 2].sigma1 &+ W[i - 7] &+ W[i - 15].sigma0 &+ W[i - 16]
        }

        var a = H[0]
        var b = H[1]
        var c = H[2]
        var d = H[3]
        var e = H[4]
        var f = H[5]
        var g = H[6]
        var h = H[7]

        for t in 0..<Self.chunkSize {
            let t1 = h &+ e.gamma1 &+ UInt32.choose(x: e, y: f, z: g) &+ Self.K[t] &+ W[t]
            let t2 = a.gamma0 &+ UInt32.major(x: a, y: b, z: c)
            
            h = g
            g = f
            f = e
            e = d &+ t1
            d = c
            c = b
            b = a
            a = t1 &+ t2
        }
        H[0] &+= a
        H[1] &+= b
        H[2] &+= c
        H[3] &+= d
        H[4] &+= e
        H[5] &+= f
        H[6] &+= g
        H[7] &+= h
    }
}
