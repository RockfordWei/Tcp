//
//  TcpServer.swift
//  
//
//  Created by Rocky Wei on 2023-02-11.
//

import Foundation

public extension TcpSocket {
    func listen() throws {
        #if os(Linux)
        let result = SwiftGlibc.listen(_socket, SOMAXCONN)
        #else
        let result = Darwin.listen(_socket, SOMAXCONN)
        #endif
        try TcpContext.assert(result: result, context: .listen)
    }
}
public extension TcpSocket {
    func accept() throws -> TcpSocket {
        var address = sockaddr()
        var size = socklen_t(MemoryLayout.size(ofValue: sockaddr_in()))
        #if os(Linux)
        let result = SwiftGlibc.accept(self._socket, &address, &size)
        #else
        let result = Darwin.accept(self._socket, &address, &size)
        #endif
        try TcpContext.assert(result: result, context: .accept)
        return TcpSocket(originalSocket: result, address: address)
    }
}
public extension TcpSocket {
    var pollFd: pollfd {
        return pollfd(fd: _socket, events: Int16(POLLIN), revents: 0)
    }
    func poll(queue: DispatchQueue? = nil) throws {
        clients = clients.filter { $0.live }
        let sockets = [self] + Array(clients)
        var fds = sockets.map { $0.pollFd }
        let nfds = nfds_t(fds.count)
        #if os(Linux)
        let result = Glibc.poll(&fds, nfds, timeoutMilliseconds)
        #else
        let result = Darwin.poll(&fds, nfds, timeoutMilliseconds)
        #endif
        guard result != 0 else { return }
        try TcpContext.assert(result: result, context: .poll)
        var group = Set(zip(sockets, fds)
            .filter { $0.1.revents == POLLIN }
            .map { $0.0 })
        if group.contains(self) {
            let client = try accept()
            clients.insert(client)
            group.remove(self)
        }
        guard let delegate = delegate else { return }
        for client in group {
            if let queue = queue {
                queue.async {
                    delegate.onDataArrival(tcpSocket: client)
                }
            } else {
                delegate.onDataArrival(tcpSocket: client)
            }
        }
    }
    func serve(queue: DispatchQueue = .global(qos: .background), wait: Bool = true) {
        guard live else { return }
        let signal = DispatchSemaphore(value: 0)
        queue.async {
            do {
                try self.poll(queue: queue)
                signal.signal()
                queue.async {
                    self.serve(queue: queue)
                }
            } catch {
                NSLog("unable to poll: \(error)")
                self.live = false
            }
        }
        if wait {
            signal.wait()
        }
    }
}
