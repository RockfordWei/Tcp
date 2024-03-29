//
//  SHA-512.swift
//  
//
//  Created by Rocky Wei on 2023-03-23.
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif
import Foundation

struct DigestAlgorithmSHA512 {
    internal static let ending: [UInt8] = [0x80]
    public let hash: [UInt8]
    public init(source: Data) throws {
        var message = source
        let length = UInt64(message.count)
        let lengthLow = length << 3
        let lengthHigh = length > 8 ? length >> 61 : 0
        
        var tailSize = SHA512Round.chunkSize - 16
        let remain = Int(length + 1) % SHA512Round.chunkSize
        if remain != tailSize {
            tailSize -= remain
            if tailSize < 0 {
                tailSize += SHA512Round.chunkSize
            }
        }
        let padding = Self.ending + [UInt8](repeating: 0, count: tailSize)
            + lengthHigh.bigEndianBytes + lengthLow.bigEndianBytes
        message.append(contentsOf: padding)
        
        let blocks = message.count / SHA512Round.chunkSize
        let round = SHA512Round()
        for index in 0..<blocks {
            let start = index * SHA512Round.chunkSize
            let end = start + SHA512Round.chunkSize
            let block = Data(message[start..<end])
            try round.calculate(block: block)
        }
        hash = round.hashValue
    }
    public init(streamReaderFileNumber: Int32) throws {
        guard streamReaderFileNumber > 0 else {
            throw NSError(domain: "invalid file number", code: 0)
        }
        var totalBytes = 0
        var index = 0
        var inProgress = true
        let round = SHA512Round()
        var lastBlock: [UInt8] = []
        while inProgress {
            var block = [UInt8](repeating: 0, count: SHA512Round.chunkSize)
            let size = block.withUnsafeMutableBytes { pointer -> Int in
                #if os(Linux)
                return Glibc.read(streamReaderFileNumber, pointer.baseAddress, SHA512Round.chunkSize)
                #else
                return Darwin.read(streamReaderFileNumber, pointer.baseAddress, SHA512Round.chunkSize)
                #endif
            }
            if size >= 0 {
                totalBytes += size
            }
            let length = UInt64(totalBytes)
            let lengthLow = length << 3
            let lengthHigh = length > 8 ? length >> 61 : 0
            if size < (SHA512Round.chunkSize - 17) {
                block = [UInt8](block[0..<size]) + Self.ending + [UInt8](repeating: 0, count: SHA512Round.chunkSize - size - 17) + lengthHigh.bigEndianBytes + lengthLow.bigEndianBytes
                inProgress = false
            } else if size < SHA512Round.chunkSize {
                block[size] = Self.ending[0]
                lastBlock = [UInt8](repeating: 0, count: SHA512Round.chunkSize - 16) + lengthHigh.bigEndianBytes + lengthLow.bigEndianBytes
                inProgress = false
            } else {
                inProgress = true
            }
            try round.calculate(block: Data(block))
            index += 1
        }
        if lastBlock.count == SHA512Round.chunkSize {
            try round.calculate(block: Data(lastBlock))
        }
        #if os(Linux)
        Glibc.close(streamReaderFileNumber)
        #else
        Darwin.close(streamReaderFileNumber)
        #endif
        hash = round.hashValue
    }
}
class SHA512Round {
    static let chunkSize = 128
    static let rounds = 80
    static let K: [UInt64] = [
        0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
        0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
        0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
        0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
        0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
        0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
        0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
        0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
        0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
        0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
        0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
        0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
        0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
        0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
        0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
        0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
        0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
        0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
        0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
        0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817
    ]
    private var H: [UInt64] = [
        0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
        0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179
    ]
    var hashValue: [UInt8] {
        return H.flatMap { $0.bigEndianBytes }
    }
    func calculate(block: Data) throws {
        guard block.count == Self.chunkSize else {
            throw NSError(domain: "invalid block size", code: 0, userInfo: [
                "expecting": Self.chunkSize,
                "actual": block.count
            ])
        }
        var W = [UInt64](repeating: 0, count: Self.rounds)
        for i in 0..<Self.rounds {
            W[i] = i < 16 ? UInt64.unpack(from: block, offset: i * 8)
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

        for t in 0..<Self.rounds {
            let t1 = h &+ e.gamma1 &+ UInt64.choose(x: e, y: f, z: g) &+ Self.K[t] &+ W[t]
            let t2 = a.gamma0 &+ UInt64.major(x: a, y: b, z: c)
            
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
