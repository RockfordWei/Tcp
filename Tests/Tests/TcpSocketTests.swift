//
//  TcpSocketTests.swift
//
//
//  Created by Rocky Wei on 2023-02-08.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif
@testable import TcpSocket
import XCTest

// swiftlint:disable implicitly_unwrapped_optional
final class TcpSocketTests: XCTestCase {
    var server: HttpServer! = nil
    let port: UInt16 = 8181
    static let randomBytes: [UInt8] = (0..<8192).map { _ -> UInt8 in
        return UInt8.random(in: 0..<255)
    }
    static let randomStruct = TestJsonStruct(id: Int.random(in: 1024..<2048), timestamp: Date(), payload: UUID().uuidString)
    let tmpPath = "/tmp/httptest.png"
    let routes: [HttpRoute] = [
        HttpRoute(api: "/api/v1/get", method: .GET) { request throws -> HttpResponse? in
            XCTAssertEqual(request.uri.parameters, ["user": "guest anonymous", "timeout": "^600"])
            return try HttpResponse(encodable: ResponseBody(error: 0))
        },
        HttpRoute(api: "/api/v1/postParameters", method: .POST) { request throws -> HttpResponse? in
            XCTAssertEqual(request.postFields, ["key1": "value1?", "key2": "value2:", "key3": "value3|"])
            return try HttpResponse(encodable: ResponseBody(error: 0))
        },
        HttpRoute(api: "/api/v1/postJson", method: .POST) { request throws -> HttpResponse? in
            let post = try request.decode(to: TestJsonStruct.self)
            XCTAssertEqual(post.id, randomStruct.id)
            XCTAssertEqual(post.timestamp, randomStruct.timestamp)
            XCTAssertEqual(post.payload, randomStruct.payload)
            return try HttpResponse(encodable: ResponseBody(error: 0))
        },
        HttpRoute(api: "/api/v1/postFiles", method: .POST) { request throws -> HttpResponse? in
            let files = request.files
            XCTAssertEqual(files.count, 3)
            let data = Data(TcpSocketTests.randomBytes)
            for file in files {
                XCTAssertEqual(file.content, data)
                print(file.attributes)
            }
            return try HttpResponse(encodable: ResponseBody(error: 0))
        }
    ]
    override func setUp() {
        super.setUp()
        do {
            let data = Data(Self.randomBytes)
            let url = try XCTUnwrap(URL(string: "file://\(tmpPath)"))
            try data.write(to: url)
            server = try HttpServer(port: port, routes: routes)
            server.webroot = "/tmp"
        } catch {
            XCTFail("cannot setup because \(error)")
        }
    }
    override func tearDown() {
        super.tearDown()
        server.live = false
        server.shutdown()
        server.close()
        unlink(tmpPath)
    }
    func curlData(command: String) throws -> Data {
        let cmd = "curl -s -0 -4 \(command)"
        NSLog("performing curl command:\n\(cmd)")
        let process = Process()
        let stdOut = Pipe()
        let stdErr = Pipe()
        process.standardOutput = stdOut
        process.standardError = stdErr
        process.arguments = ["-c", cmd]
        process.executableURL = URL(string: "file:///bin/bash")
        process.standardInput = nil
        try process.run()
        process.waitUntilExit()
        let errData = stdErr.fileHandleForReading.readDataToEndOfFile()
        if !errData.isEmpty {
            if let errText = String(data: errData, encoding: .utf8) {
                NSLog(errText)
            } else {
                NSLog("curl stderr output: \(errData.count) bytes")
            }
        }
        let data = stdOut.fileHandleForReading.readDataToEndOfFile()
        if let text = String(data: data, encoding: .utf8) {
            NSLog("response: \(text)")
        }
        return data
    }
    func curl<T: Decodable>(command: String) throws -> T? {
        let data = try curlData(command: command)
        return try JSONDecoder().decode(T.self, from: data)
    }
    func curlPostFile<T: Decodable>(files: [String], url: String) throws -> T? {
        let fileString = files.enumerated().map { "-F 'file\($0.offset)=@\($0.element)'" }.joined(separator: " ")
        let command = "\(fileString) '\(url)'"
        return try curl(command: command)
    }
    func curlPostParameters<T: Decodable>(parameters: [String: String], url: String) throws -> T? {
        let parameterString = parameters.map { "\($0.key.urlEncoded)=\($0.value.urlEncoded)" }.joined(separator: "&")
        let command = "-X POST -d '\(parameterString)' '\(url)'"
        return try curl(command: command)
    }
    func testGet() throws {
        let urlString = "'http://localhost:\(port)/api/v1/get?user=\("guest anonymous".urlEncoded)&timeout=\("^600".urlEncoded)'"
        let response: ResponseBody? = try curl(command: urlString)
        let resp = try XCTUnwrap(response)
        XCTAssertEqual(resp.error, 0)
    }
    func testPostParameters() throws {
        let urlString = "http://localhost:\(port)/api/v1/postParameters"
        let response: ResponseBody? = try curlPostParameters(parameters: ["key1": "value1?", "key2": "value2:", "key3": "value3|"], url: urlString)
        let resp = try XCTUnwrap(response)
        XCTAssertEqual(resp.error, 0)
    }
    func testPostJson() throws {
        let urlString = "http://localhost:\(port)/api/v1/postJson"
        let jsonData = try JSONEncoder().encode(Self.randomStruct)
        let jsonString = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
        let jsonResponse = try curlData(command: "-X POST -H 'Content-Type: application/json' --data '\(jsonString)' '\(urlString)'")
        let response = try JSONDecoder().decode(ResponseBody.self, from: jsonResponse)
        XCTAssertEqual(response.error, 0)
    }
    func testPostFiles() throws {
        let urlString = "http://localhost:\(port)/api/v1/postFiles"
        let response: ResponseBody? = try curlPostFile(files: [tmpPath, tmpPath, tmpPath], url: urlString)
        let resp = try XCTUnwrap(response)
        XCTAssertEqual(resp.error, 0)
    }
    func testStaticFile() throws {
        let urlString = "http://localhost:\(port)/httptest.png"
        let result = try curlData(command: "--output /tmp/result.png '\(urlString)'")
        NSLog("fetch result: \(result)")
        let localUrl = try XCTUnwrap(URL(string: "file:///tmp/result.png"))
        let data = try Data(contentsOf: localUrl)
        XCTAssertEqual(data, Data(Self.randomBytes))
    }
    static var allTests = [
        ("testGet", testGet),
        ("testPostParameters", testPostParameters),
        ("testPostFiles", testPostFiles),
        ("testPostJson", testPostJson),
        ("testStaticFile", testStaticFile)
    ]
}
struct ResponseBody: Codable {
    let error: Int
}
struct RequestBody: Codable {
    let content: String
    let timestamp: Date
}
struct TestJsonStruct: Codable {
    let id: Int
    let timestamp: Date
    let payload: String
}
