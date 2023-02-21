//
//  HTTP11.swift
//  
//
//  Created by Rocky Wei on 2/20/23.
//

import Foundation

open class HttpResponse {
    internal let version = "HTTP/1.1"
    public var headers: [String: String] = [:]
    internal let body: Data
    internal var code = 200
    public init(content: String? = nil) {
        if let content = content {
            body = content.data(using: .utf8) ?? Data()
        } else {
            body = Data()
        }
    }
    public init(raw: Data) {
        body = raw
    }
    public func encode() throws -> Data {
        headers["date"] = "\(Date())"
        headers["content-length"] = "\(body.count)"
        let content = (["\(version) \(code)"] + headers.map { "\($0.key): \($0.value)" }).joined(separator: "\r\n") + "\r\n\r\n"
        guard let payload = content.data(using: .utf8) else {
            throw NSError(domain: "invalid payload encoding", code: 0)
        }
        return payload + body
    }
}
