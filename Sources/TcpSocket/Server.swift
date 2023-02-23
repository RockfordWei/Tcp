//
//  Server.swift
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
        guard result == -1 else {
            return
        }
        let reason: String
        switch errno {
        case EADDRINUSE: reason = "Another socket is already listening on the same port."
        case EBADF: reason = "The argument sockfd is not a valid file descriptor."
        case ENOTSOCK: reason = "The file descriptor sockfd does not refer to a socket."
        case EOPNOTSUPP: reason = "The socket is not of a type that supports the listen() operation."
        default: reason = "unable to listen"
        }
        throw Exception.fail(reason: reason)
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
        guard result == -1 else {
            return TcpSocket(originalSocket: result, address: address)
        }
        let reason: String
        switch errno {
        case EAGAIN, EWOULDBLOCK: reason = "The socket is marked nonblocking and no connections are present to be accepted.  POSIX.1-2001 and POSIX.1-2008 allow either error to be returned for this case, and do not require these constants to have the same value, so a portable application should check for both possibilities."
        case EBADF: reason = "sockfd is not an open file descriptor."
        case ECONNABORTED: reason = "A connection has been aborted."
        case EFAULT: reason = "The addr argument is not in a writable part of the user address space."
        case EINTR: reason = "The system call was interrupted by a signal that was caught before a valid connection arrived; see signal(7)."
        case EINVAL: reason = "Socket is not listening for connections, or addrlen is invalid (e.g., is negative), or (accept4()) invalid value in flags."
        case EMFILE: reason = "The per-process limit on the number of open file descriptors has been reached."
        case ENFILE: reason = "The system-wide limit on the total number of open files has been reached."
        case ENOBUFS, ENOMEM: reason = "Not enough free memory.  This often means that the memory allocation is limited by the socket buffer limits, not by the system memory."
        case ENOTSOCK: reason = "The file descriptor sockfd does not refer to a socket."
        case EOPNOTSUPP: reason = "The referenced socket is not of type SOCK_STREAM."
        case EPERM: reason = "Firewall rules forbid connection."
        case EPROTO: reason = "Protocol error."
        default: reason = "unable to accept"
        }
        throw Exception.fail(reason: reason)
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
        if result == -1 {
            let reason: String
            switch errno {
            case EAGAIN: reason = "Allocation of internal data structures fails.  A sub-sequent subsequent sequent request may succeed."
            case EFAULT: reason = "Fds points outside the process's allocated address space."
            case EINTR: reason = "A signal is delivered before the time limit expires and before any of the selected events occurs."
            case EINVAL: reason = "The nfds argument is greater than OPEN_MAX or the timeout argument is less than -1."
            default: reason = "unable to poll"
            }
            throw Exception.fail(reason: reason)
        }
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
    func serve(queue: DispatchQueue = .global(qos: .background)) {
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
        signal.wait()
    }
}
