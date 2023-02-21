import Foundation
import TcpSocket

let port: UInt16
if CommandLine.argc > 1,
    let textPort = CommandLine.arguments.last,
   let _port = UInt16(textPort) {
    port = _port
} else {
    port = 8181
}
NSLog("preparing tcp socket on port \(port)")
let server = try TcpSocket()
try server.bind(port: port)
try server.listen()
server.delegate = HttpDemoServer()
server.serve()
while server.live {
    guard let text = readLine()?.lowercased() else {
        continue
    }
    if text.contains("close") || text.contains("quit") || text.contains("exit") {
        server.live = false
    }
}
server.live = false
server.shutdown()
server.close()

struct DemoResponseBody: Codable {
    let error: Int
}
class HttpDemoServer: TcpSocketDelegate {
    func onDataArrival(tcpSocket: TcpSocket) {
        do {
            let request = try tcpSocket.recv()
            if let text = String(data: request, encoding: .utf8) {
                NSLog("\n(recv)\n\(text)\n(end)")
            }
            let response = try HttpResponse(encodable: DemoResponseBody(error: 0))
            let content = try response.encode()
            try tcpSocket.send(data: content)
        } catch {
            NSLog("\(error)")
        }
        tcpSocket.shutdown()
        tcpSocket.close()
        tcpSocket.live = false
    }
}
