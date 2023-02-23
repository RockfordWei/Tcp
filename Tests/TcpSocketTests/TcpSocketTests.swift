import Foundation
#if os(Linux)
import FoundationNetworking
#endif
@testable import TcpSocket
import XCTest

// swiftlint:disable implicitly_unwrapped_optional
final class TcpSocketTests: XCTestCase {
    var server: TcpSocket! = nil
    let port: UInt16 = 8181
    override func setUp() {
        super.setUp()
        do {
            let echo = HttpTestServer()
            server = try TcpSocket()
            try server.bind(port: port)
            try server.listen()
            server.delegate = echo
            server.serve()
        } catch {
            XCTFail("cannot setup because \(error)")
        }
    }
    override func tearDown() {
        super.tearDown()
        server.live = false
        server.shutdown()
        server.close()
    }
    func curl<T: Decodable>(url: String) throws -> T? {
        let process = Process()
        let stdOut = Pipe()
        let stdErr = Pipe()
        process.standardOutput = stdOut
        process.standardError = stdErr
        process.arguments = ["-c", "curl -s -0 -4 '\(url)'"]
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
        #if os(Linux)
        let response: ResponseBody? = try curl(url: urlString)
        let resp = try XCTUnwrap(response)
        XCTAssertEqual(resp.error, 0)
        #else
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "invalid url", code: 0)
        }
        let request = URLRequest(url: url)
        let expUrl = expectation(description: "url")
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
                    expUrl.fulfill()
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
        wait(for: [expUrl], timeout: 10)
        #endif
    }
    static var allTests = [
        ("testCurl", testCurl)
    ]
}
struct ResponseBody: Codable {
    let error: Int
}
class HttpTestServer: TcpSocketDelegate {
    func onDataArrival(tcpSocket: TcpSocket) {
        do {
            let request = try tcpSocket.recv()
            guard !request.isEmpty else {
                return
            }
            if let text = String(data: request, encoding: .utf8) {
                NSLog("request: \(text)")
            }
            let httpRequest = try HttpRequest(request: request)
            XCTAssertEqual(httpRequest.uri.raw, "/api/v1/get?user=guest&feedback=none")
            XCTAssertEqual(httpRequest.uri.path, ["api", "v1", "get"])
            XCTAssertEqual(httpRequest.uri.parameters, ["feedback": "none", "user": "guest"])
            XCTAssertTrue(httpRequest.body.isEmpty)
            let response = try HttpResponse(encodable: ResponseBody(error: 0))
            let content = try response.encode()
            try tcpSocket.send(data: content)
        } catch {
            XCTFail("\(error)")
        }
        tcpSocket.shutdown()
        tcpSocket.close()
        tcpSocket.live = false
    }
}
