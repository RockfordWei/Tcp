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
    let tmpPath = "/tmp/httptest.bin"
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
    func curl<T: Decodable>(filePath: String, url: String) throws -> T? {
        let process = Process()
        let stdOut = Pipe()
        let stdErr = Pipe()
        process.standardOutput = stdOut
        process.standardError = stdErr
        process.arguments = ["-c", "curl -s -0 -4 -F 'data=@\(filePath)' '\(url)'"]
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
    func testCurl() throws {
        let urlString = "http://localhost:8181/api/v1/get?user=guest&feedback=none"
        #if os(Linux) || os(macOS)
        let response: ResponseBody? = try curl(filePath: tmpPath, url: urlString)
        let resp = try XCTUnwrap(response)
        XCTAssertEqual(resp.error, 0)
        #else
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "invalid url", code: 0)
        }
        let request = URLRequest(url: url)
        let exp = expectation(description: "url")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                if let text = String(data: data, encoding: .utf8) {
                    NSLog("response text: \(text)")
                } else {
                    NSLog("response data: \(data)")
                }
                do {
                    let responseBody = try JSONDecoder().decode(ResponseBody.self, from: data)
                    XCTAssertEqual(responseBody.error, 0)
                    exp.fulfill()
                } catch {
                    XCTFail("\(error)")
                }
            }
            if let error = error {
                NSLog("response error: \(error)")
            }
            if let response = response {
                NSLog("response: \(response)")
            }
        }
        task.resume()
        wait(for: [exp], timeout: 10)
        #endif
    }
    static var allTests = [
        ("testCurl", testCurl)
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
        XCTAssertEqual(request.uri.raw, "/api/v1/get?user=guest&feedback=none")
        XCTAssertEqual(request.uri.path, ["api", "v1", "get"])
        XCTAssertEqual(request.uri.parameters, ["feedback": "none", "user": "guest"])
        XCTAssertEqual(request.method, .POST)
        let range = try XCTUnwrap(request.body.firstRange(of: TcpSocketTests.randomBytes))
        NSLog("found payload: \(range)")
        return try HttpResponse(encodable: ResponseBody(error: 0))
    }
}
