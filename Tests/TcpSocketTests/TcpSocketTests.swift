import Foundation
#if os(Linux)
import FoundationNetworking
#endif
@testable import TcpSocket
import XCTest

// swiftlint:disable implicitly_unwrapped_optional
final class TcpSocketTests: XCTestCase {
    var server: TcpSocket! = nil
    let exp = XCTestExpectation(description: "echo")
    let port: UInt16 = 8181
    override func setUp() {
        super.setUp()
        do {
            let echo = HttpTestServer(exp: exp)
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
    func testEcho() throws {
        let client = try TcpSocket()
        try client.connect(to: "0.0.0.0", with: port)
        try client.send(text: "hello")
        wait(for: [exp], timeout: 5)
    }
    func testUrlSession() throws {
        guard let url = URL(string: "http://localhost:8181/") else {
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
        wait(for: [expUrl], timeout: 5)
    }
    func testDataSplitGood() throws {
        let text = try XCTUnwrap("this\r\n\r\nis\r\n\r\na\r\n\r\ngood\r\n\r\ntest".data(using: .utf8))
        let results = text.split(by: "\r\n\r\n")
        XCTAssertFalse(results.isEmpty)
        let words = results.compactMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(words, ["this", "is", "a", "good", "test"])
    }
    func testDataSplitOneHead() throws {
        let text = try XCTUnwrap("this\r\n\r\n".data(using: .utf8))
        let results = text.split(by: "\r\n\r\n")
        let words = results.compactMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(words, ["this"])
    }
    func testDataSplitOneTail() throws {
        let text = try XCTUnwrap("\r\n\r\nthis".data(using: .utf8))
        let results = text.split(by: "\r\n\r\n")
        let words = results.compactMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(words, ["this"])
    }
    func testDataSplitEmpty() throws {
        let results = Data().split(by: "\r\n\r\n")
        XCTAssertTrue(results.isEmpty)
    }
    func testDataSplitBad() throws {
        let text = try XCTUnwrap("this is a test".data(using: .utf8))
        let results = text.split(by: "\r\n\r\n")
        let words = results.compactMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(words, ["this is a test"])
    }
    static var allTests = [
        ("testEcho", testEcho),
        ("testDataSplitGood", testDataSplitGood),
        ("testDataSplitOneHead", testDataSplitOneHead),
        ("testDataSplitOneTail", testDataSplitOneTail),
        ("testDataSplitEmpty", testDataSplitEmpty),
        ("testDataSplitBad", testDataSplitBad),
        ("testUrlSession", testUrlSession)
    ]
}
struct ResponseBody: Codable {
    let error: Int
}
class HttpTestServer: TcpSocketDelegate {
    let exp: XCTestExpectation
    init(exp: XCTestExpectation) {
        self.exp = exp
    }
    func onDataArrival(tcpSocket: TcpSocket) {
        do {
            let request = try tcpSocket.recv()
            if let text = String(data: request, encoding: .utf8) {
                NSLog("\n(recv)\n\(text)\n(end)")
            }
            let response = try HttpResponse(encodable: ResponseBody(error: 0))
            let content = try response.encode()
            try tcpSocket.send(data: content)
        } catch {
            XCTFail("\(error)")
        }
        tcpSocket.shutdown()
        tcpSocket.close()
        tcpSocket.live = false
        exp.fulfill()
    }
}
