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
    public init(raw: Data) {
        body = raw
    }
    public convenience init(content: String? = nil) {
        let data = content?.data(using: .utf8) ?? Data()
        self.init(raw: data)
    }
    public convenience init<T: Encodable>(encodable: T) throws {
        let data = try JSONEncoder().encode(encodable)
        self.init(raw: data)
    }
    public func encode() throws -> Data {
        headers["date"] = "\(Date())"
        headers["content-length"] = "\(body.count)"
        let content = (["\(version) \(code)"] + headers.map { "\($0.key): \($0.value)" })
            .joined(separator: "\r\n") + "\r\n\r\n"
        guard let payload = content.data(using: .utf8) else {
            throw NSError(domain: "invalid payload encoding", code: 0)
        }
        return payload + body
    }
}

public extension Data {
    func split(by separator: String) -> [Data] {
        guard !isEmpty else {
            return []
        }
        guard let seq = separator.data(using: .utf8) else {
            return [self]
        }
        var remains = self
        var results = [Data]()
        while !remains.isEmpty {
            if let location = remains.firstRange(of: seq) {
                let head = remains[remains.startIndex..<location.lowerBound]
                if !head.isEmpty {
                    results.append(head)
                }
                remains = remains[location.upperBound..<remains.endIndex]
            } else {
                results.append(remains)
                break
            }
        }
        return results
    }
}
