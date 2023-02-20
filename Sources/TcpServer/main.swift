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
server.delegate = EchoServer()
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

class EchoServer: TcpSocketDelegate {
    func onDataArrival(tcpSocket: TcpSocket) {
        var shouldTerminated = false
        do {
            let request = try tcpSocket.recv()
            try tcpSocket.send(data: request)
            if let text = String(data: request, encoding: .utf8)?.lowercased(),
               text.contains("close") || text.contains("quit") || text.contains("exit") {
                shouldTerminated = true
            }
        } catch {
            NSLog("request failed because \(error)")
            shouldTerminated = true
        }
        if shouldTerminated {
            tcpSocket.shutdown()
            tcpSocket.close()
            tcpSocket.live = false
        }
    }
}
