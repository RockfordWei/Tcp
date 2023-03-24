//
//  hmac.swift
//  
//
//  Created by Rocky Wei on 3/2/23.
//

import Foundation

public struct HMAC {
    public static func digest(source: Data, by key: Data, using algorithm: DigestAlgorithm = .SHA256) throws -> Data {
        let blockSize = DigestAlgorithm.getBlockSize(algorithm: algorithm)
        let normalizedKey: Data
        if key.count > blockSize {
            let keyHash = try key.digest(algorithm: algorithm)
            let padding = Data(repeating: 0, count: blockSize - keyHash.count)
            normalizedKey = keyHash + padding
        } else if key.count < blockSize {
            var mutableKey = key
            mutableKey.append(contentsOf: Data(repeating: 0, count: blockSize - key.count))
            normalizedKey = mutableKey
        } else {
            normalizedKey = key
        }
        guard normalizedKey.count == blockSize else {
            throw NSError(domain: "unexpected normalized key length", code: 0, userInfo: [
                "expecting": blockSize,
                "actual": normalizedKey.count
            ])
        }
        let innerKey = normalizedKey.map { UInt8(0x36) ^ $0 }
        let outerKey = normalizedKey.map { UInt8(0x5c) ^ $0 }
        let innerData = try hash(pad: Data(innerKey), source: source, using: algorithm)
        return try hash(pad: Data(outerKey), source: innerData, using: algorithm)
    }
    private static func hash(pad: Data, source: Data, using algorithm: DigestAlgorithm = .SHA256) throws -> Data {
        return try Data(pad + source).digest(algorithm: algorithm)
    }
    public static func digestHex(message: String, by key: String, using algorithm: DigestAlgorithm = .SHA256) throws -> String {
        let source = message.data(using: .utf8) ?? Data()
        let keyData = key.data(using: .utf8) ?? Data()
        return try digest(source: source, by: keyData, using: algorithm).hex
    }
    public static func digestBase64(message: String, by key: String, using algorithm: DigestAlgorithm = .SHA256) throws -> String {
        let source = message.data(using: .utf8) ?? Data()
        let keyData = key.data(using: .utf8) ?? Data()
        return try digest(source: source, by: keyData, using: algorithm).base64EncodedString()
    }
}
