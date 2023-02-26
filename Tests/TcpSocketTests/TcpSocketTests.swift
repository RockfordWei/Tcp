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
    static let randomBytes: [UInt8] = (0..<8000).map { _ -> UInt8 in
        return UInt8.random(in: 0..<255)
    }
    let tmpPath = "/tmp/httptest.png"
    override func setUp() {
        super.setUp()
        do {
            let data = Data(Self.randomBytes)
            let url = try XCTUnwrap(URL(string: "file://\(tmpPath)"))
            try data.write(to: url)
            let web = HttpTestServerDelegate()
            server = try HttpServer(port: port, delegate: web)
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
    func curl<T: Decodable>(command: String) throws -> T? {
        let process = Process()
        let stdOut = Pipe()
        let stdErr = Pipe()
        process.standardOutput = stdOut
        process.standardError = stdErr
        process.arguments = ["-c", "curl -s -0 -4 \(command)"]
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
        let urlString = "'http://localhost:8181/api/v1/get?user=guest&timeout=600'"
        let response: ResponseBody? = try curl(command: urlString)
        let resp = try XCTUnwrap(response)
        XCTAssertEqual(resp.error, 0)
    }
    func testPostParameters() throws {
        let urlString = "http://localhost:8181/api/v1/postParameters"
        let response: ResponseBody? = try curlPostParameters(parameters: ["key1": "value1", "key2": "value2", "key3": "value3"], url: urlString)
        let resp = try XCTUnwrap(response)
        XCTAssertEqual(resp.error, 0)
    }
    func testPostFiles() throws {
        let urlString = "http://localhost:8181/api/v1/postFiles"
        let response: ResponseBody? = try curlPostFile(files: [tmpPath, tmpPath, tmpPath], url: urlString)
        let resp = try XCTUnwrap(response)
        XCTAssertEqual(resp.error, 0)
    }
    static var allTests = [
        ("testGet", testGet),
        ("testPostParameters", testPostParameters),
        ("testPostFiles", testPostFiles)
    ]
}
struct ResponseBody: Codable {
    let error: Int
}
struct RequestBody: Codable {
    let content: String
    let timestamp: Date
}
class HttpTestServerDelegate: HttpServerDelegate {
    func onSession(request: HttpRequest) throws -> HttpResponse? {
        print(request.headers)
        XCTAssertEqual(request.uri.path.count, 3)
        XCTAssertEqual(request.uri.path[0], "api")
        XCTAssertEqual(request.uri.path[1], "v1")
        let api = request.uri.path[2]
        switch api {
        case "get":
            XCTAssertEqual(request.method, .GET)
            XCTAssertEqual(request.uri.parameters, ["user": "guest", "timeout": "600"])
        case "postParameters":
            XCTAssertEqual(request.method, .POST)
            XCTAssertEqual(request.postFields, ["key1": "value1", "key2": "value2", "key3": "value3"])
        case "postFiles":
            XCTAssertEqual(request.method, .POST)
            let files = request.files
            XCTAssertEqual(files.count, 3)
            let data = Data(TcpSocketTests.randomBytes)
            for file in files {
                XCTAssertEqual(file.content, data)
                print(file.attributes)
            }
        default:
            XCTFail("unknown api: \(api)")
        }
        return try HttpResponse(encodable: ResponseBody(error: 0))
    }
}
