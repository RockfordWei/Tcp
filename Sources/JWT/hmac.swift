//
//  hmac.swift
//  
//
//  Created by Rocky Wei on 3/2/23.
//

import Foundation

public struct HMAC {
    public static func digest(source: Data, by key: Data, using algorithm: DigestAlgorithm = .SHA256) -> Data {
        let blockSize = 64
        let normalizedKey: Data
        if key.count > blockSize {
            normalizedKey = key.digest(algorithm: algorithm)
        } else if key.count < blockSize {
            var mutableKey = key
            mutableKey.append(contentsOf: Data(repeating: 0, count: blockSize - key.count))
            normalizedKey = mutableKey
        } else {
            normalizedKey = key
        }
        assert(normalizedKey.count == blockSize)
        let innerKey = normalizedKey.map { UInt8(0x36) ^ $0 }
        let outerKey = normalizedKey.map { UInt8(0x5c) ^ $0 }
        let innerData = hash(pad: Data(innerKey), source: source)
        return hash(pad: Data(outerKey), source: innerData)
    }
    private static func hash(pad: Data, source: Data, using algorithm: DigestAlgorithm = .SHA256) -> Data {
        return Data(pad + source).digest(algorithm: algorithm)
    }
    public static func digestHex(message: String, by key: String) -> String {
        let source = message.data(using: .utf8) ?? Data()
        let keyData = key.data(using: .utf8) ?? Data()
        return digest(source: source, by: keyData).hex
    }
    public static func digestBase64(message: String, by key: String) -> String {
        let source = message.data(using: .utf8) ?? Data()
        let keyData = key.data(using: .utf8) ?? Data()
        return digest(source: source, by: keyData).base64EncodedString()
    }
}
