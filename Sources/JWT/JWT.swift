//
//  JWT.swift
//  
//
//  Created by Rocky Wei on 3/2/23.
//

import Foundation

public struct JWTHead: Codable {
    let alg: String
    public init(alg: String) {
        self.alg = alg
    }
    var algorithm: DigestAlgorithm? {
        return DigestAlgorithm(rawValue: alg) ?? DigestAlgorithm(rawValue: alg.replacingOccurrences(of: "HS", with: "SHA"))
    }
}
public struct JWT {
    static func encode<T: Codable>(claims: T, secret: String, algorithm: String = "HS256") throws -> String {
        let head = JWTHead(alg: algorithm)
        guard let algo = head.algorithm else {
            throw NSError(domain: "invalid algorithm \(algorithm)", code: 0)
        }
        let jsonEncoder = JSONEncoder()
        let headText = try jsonEncoder.encode(head).base64EncodedString()
        let payloadText = try jsonEncoder.encode(claims).base64EncodedString()
        let source = [headText, payloadText, secret].joined(separator: ".")
        let hash = HMAC.digestBase64(message: source, by: secret, using: algo)
        return [headText, payloadText, hash].joined(separator: ".")
    }
    static func decode<T: Codable>(token: String, secret: String) throws -> T {
        let parts = token.split(separator: ".")
        guard parts.count == 3,
              let headEncodedData = parts[0].data(using: .utf8),
              let headData = Data(base64Encoded: headEncodedData),
              let payloadEncodedData = parts[1].data(using: .utf8),
              let payloadData = Data(base64Encoded: payloadEncodedData) else {
            throw NSError(domain: "invalid JWT token", code: 0)
        }
        let jsonDecoder = JSONDecoder()
        let head = try jsonDecoder.decode(JWTHead.self, from: headData)
        guard let algo = head.algorithm else {
            throw NSError(domain: "algorithm \(head.alg) is not implemented", code: 0)
        }
        let source = [String(parts[0]), String(parts[1]), secret].joined(separator: ".")
        let hash = HMAC.digestBase64(message: source, by: secret, using: algo)
        guard hash == String(parts[2]) else {
            throw NSError(domain: "signature is not matched", code: 0)
        }
        return try jsonDecoder.decode(T.self, from: payloadData)
    }
}
