import Foundation
#if os(Linux)
import FoundationNetworking
#endif
import XCTest
@testable import TcpSocket

final class TcpSocketTests: XCTestCase {
    var server: TcpSocket!
    let exp = XCTestExpectation(description: "echo")
    let port: UInt16 = 8181
    override func setUp() {
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
        URLSession.shared.dataTask(with: request) { data, response, error in
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
        }.resume()
        wait(for: [expUrl], timeout: 5)
    }
    static var allTests = [
        ("testEcho", testEcho),
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
