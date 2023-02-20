import XCTest
@testable import TcpSocket

final class TcpSocketTests: XCTestCase {
    var server: TcpSocket!
    let exp = XCTestExpectation(description: "echo")
    let port: UInt16 = 8181
    override func setUp() {
        do {
            let echo = EchoServer(exp: exp)
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
                NSLog("\(data)")
            }
            if let error = error {
                NSLog("\(error)")
            }
            if let response = response {
                NSLog("\(response)")
            }
            expUrl.fulfill()
        }.resume()
        wait(for: [expUrl], timeout: 5)
    }
    static var allTests = [
        ("testEcho", testEcho),
        ("testUrlSession", testUrlSession)
    ]
}

class EchoServer: TcpSocketDelegate {
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
            try tcpSocket.send(data: request)
        } catch {
            XCTFail("\(error)")
        }
        tcpSocket.shutdown()
        tcpSocket.close()
        tcpSocket.live = false
        exp.fulfill()
    }
}
