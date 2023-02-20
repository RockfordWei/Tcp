import XCTest
@testable import TcpSocket

final class TcpSocketTests: XCTestCase {
    func testEcho() throws {
        let exp = XCTestExpectation(description: "echo")
        let echo = EchoServer(exp: exp)
        let server = try TcpSocket()
        let port: UInt16 = 8181
        try server.bind(port: port)
        try server.listen()
        server.delegate = echo
        let queue = DispatchQueue.global(qos: .background)
        server.serve(queue: queue)
        let client = try TcpSocket()
        try client.connect(to: "0.0.0.0", with: port)
        try client.send(text: "hello")
        wait(for: [exp], timeout: 5)
        server.live = false
        server.shutdown()
        server.close()
    }
    static var allTests = [
        ("testEcho", testEcho)
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
