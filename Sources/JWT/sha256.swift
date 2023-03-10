import Foundation

public struct SHA256 {
    private static let K: [UInt32] = [
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

    public let hash: [UInt8]
    public init(source: Data) {
        var message = source
        let length = UInt64(message.count * 8)
        message.append(0x80)
        let chunkSize = 64
        var tailSize = chunkSize - 8
        let remain = message.count % chunkSize
        if remain != tailSize {
            tailSize -= remain
            if tailSize < 0 {
                tailSize += chunkSize
            }
        }
        let padding = [UInt8](repeating: 0, count: tailSize)
        message.append(contentsOf: padding)
        message.append(contentsOf: length.bytesInHighEndFirstOrder)
        
        var H: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        ]

        let blocks = message.count / chunkSize
        for index in 0..<blocks {
            let start = index * chunkSize
            let end = start + chunkSize
            let messageBlock = Data(message[start..<end])
            var messageSchedule: [[UInt8]] = (0..<chunkSize).map { _ in
                return [UInt8]()
            }
            for t in 0..<chunkSize {
                let schedule: [UInt8]
                if t < 16 {
                    let i = t * 4
                    let j = i + 4
                    schedule = [UInt8](messageBlock[i..<j])
                } else {
                    let term1 = messageSchedule[t - 2].unpack().sigma1
                    let term2 = messageSchedule[t - 7].unpack()
                    let term3 = messageSchedule[t - 15].unpack().sigma0
                    let term4 = messageSchedule[t - 16].unpack()
                    let word = term1 &+ term2 &+ term3 &+ term4
                    schedule = UInt32(word).bytesInHighEndFirstOrder
                }
                messageSchedule[t] = schedule
            }
            
            var a = H[0]
            var b = H[1]
            var c = H[2]
            var d = H[3]
            var e = H[4]
            var f = H[5]
            var g = H[6]
            var h = H[7]

            for t in 0..<64 {
                let t1 = h &+ e.gamma1 &+ UInt32.choose(x: e, y: f, z: g) &+ Self.K[t] &+ messageSchedule[t].unpack()
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
            H[0] = H[0] &+ a
            H[1] = H[1] &+ b
            H[2] = H[2] &+ c
            H[3] = H[3] &+ d
            H[4] = H[4] &+ e
            H[5] = H[5] &+ f
            H[6] = H[6] &+ g
            H[7] = H[7] &+ h
        }
        hash = H.flatMap { $0.bytesInHighEndFirstOrder }
    }
}
