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
    public enum Algorithm: String {
        case HS256
    }
    var algorithm: Algorithm? {
        return Algorithm(rawValue: alg)
    }
}
public struct JWT {
    static func encode<T: Codable>(claims: T, secret: String) throws -> String {
        let head = JWTHead(alg: JWTHead.Algorithm.HS256.rawValue)
        let jsonEncoder = JSONEncoder()
        let headText = try jsonEncoder.encode(head).base64EncodedString()
        let payloadText = try jsonEncoder.encode(claims).base64EncodedString()
        let source = [headText, payloadText, secret].joined(separator: ".")
        let hash = HMAC.digestBase64(message: source, by: secret)
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
        guard head.algorithm == .HS256 else {
            throw NSError(domain: "algorithm \(head.alg) is not implemented", code: 0)
        }
        let source = [String(parts[0]), String(parts[1]), secret].joined(separator: ".")
        let hash = HMAC.digestBase64(message: source, by: secret)
        guard hash == String(parts[2]) else {
            throw NSError(domain: "signature is not matched", code: 0)
        }
        return try jsonDecoder.decode(T.self, from: payloadData)
    }
}
