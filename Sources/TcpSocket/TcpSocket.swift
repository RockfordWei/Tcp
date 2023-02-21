#if os(Linux)
import Glibc
#else
import Darwin
#endif
import Foundation
public protocol TcpSocketDelegate: AnyObject {
    func onDataArrival(tcpSocket: TcpSocket)
}
open class TcpSocket {
    internal let _socket: Int32
    public enum ShutdownMethod {
        case read
        case write
        case both
    }
    public var socketFD: Int {
        return Int(_socket)
    }
    internal var _ip: String = "0.0.0.0"
    internal var _port: UInt16 = 0
    public var timeoutMilliseconds: Int32 = 100
    public var ip: String {
        return _ip
    }
    public var port: UInt16 {
        return _port
    }
    public var live = true
    public var delegate: TcpSocketDelegate?
    internal var clients: Set<TcpSocket> = []
    public init(originalSocket: Int32, ipAddress: String, port: UInt16) {
        _socket = originalSocket
        _ip = ipAddress
        _port = port
    }
    public convenience init(originalSocket: Int32, address: sockaddr) {
        var addr = address
        let (ipAddress, port): (String, UInt16) = withUnsafePointer(to: &addr) { baseAddress -> (String, UInt16) in
            let placeholder = sockaddr_in()
            let size = MemoryLayout.size(ofValue: placeholder)
            return baseAddress.withMemoryRebound(to: sockaddr_in.self, capacity: size) { pointer -> (String, UInt16) in
                let ip = String(cString: inet_ntoa(pointer.pointee.sin_addr))
                let port = pointer.pointee.sin_port.byteSwapped
                return (ip, port)
            }
        }
        self.init(originalSocket: originalSocket, ipAddress: ipAddress, port: port)
    }
    public init() throws {
        #if os(Linux)
        _socket = socket(AF_INET, 1, Int32(IPPROTO_TCP))
        #else
        _socket = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        guard _socket > 0 else {
            throw Exception.fail(reason: "unable to create socket")
        }
        var option: Int32 = 1
        let result = setsockopt(_socket, SOL_SOCKET, SO_REUSEADDR, &option, socklen_t(MemoryLayout.size(ofValue: option)))
        guard result == -1 else {
            return
        }
        let reason: String
        switch errno {
        case EBADF: reason = "The argument sockfd is not a valid descriptor."
        case EFAULT: reason = "The address pointed to by optval is not in a valid part of the process address space. For getsockopt(), this error may also be returned if optlen is not in a valid part of the process address space."
        case EINVAL: reason = "optlen invalid in setsockopt(). In some cases this error can also occur for an invalid value in optval (e.g., for the IP_ADD_MEMBERSHIP option described in ip(7))."
        case ENOPROTOOPT: reason = "The option is unknown at the level indicated."
        case ENOTSOCK: reason = "The argument sockfd is a file, not a socket."
        default: reason = "unable to set socket option without any reasons"
        }
        throw Exception.fail(reason: reason)
    }
    public func shutdown(method: ShutdownMethod = .both) {
        let value: Int32
        switch method {
        case .read: value = Int32(SHUT_RD)
        case .write: value = Int32(SHUT_WR)
        default: value = Int32(SHUT_RDWR)
        }
        #if os(Linux)
        Glibc.shutdown(_socket, value)
        #else
        Darwin.shutdown(_socket, value)
        #endif
    }
    public func close() {
        #if os(Linux)
        Glibc.close(_socket)
        #else
        Darwin.close(_socket)
        #endif
    }
}
public extension TcpSocket {
    static func withAddress<Result>(ipAddress: String = "0.0.0.0", port: UInt16, perform operation: @escaping (UnsafePointer<sockaddr>, socklen_t) -> Result) -> Result {
        var host = sockaddr_in()
        host.sin_family = sa_family_t(AF_INET)
        host.sin_port = in_port_t(port.byteSwapped)
        host.sin_addr = in_addr(s_addr: inet_addr(ipAddress))
        let size = socklen_t(MemoryLayout.size(ofValue: host))
        return withUnsafePointer(to: &host) { baseAddress -> Result in
            return baseAddress.withMemoryRebound(to: sockaddr.self, capacity: Int(size)) { pointer -> Result in
                return operation(pointer, size)
            }
        }
    }
}
public extension TcpSocket {
    func bind(ipAddress: String = "0.0.0.0", port: UInt16) throws {
        self._ip = ipAddress
        self._port = port
        let result = Self.withAddress(ipAddress: ipAddress, port: port) { pointer, size -> Int32 in
            #if os(Linux)
            return Glibc.bind(self._socket, pointer, size)
            #else
            return Darwin.bind(self._socket, pointer, size)
            #endif
        }
        guard result == -1 else {
            return
        }
        let reason: String
        switch errno {
        case EACCES: reason = "The address is protected, and the user is not the superuser."
        case EADDRINUSE: reason = "The given address is already in use."
        case EBADF: reason = "sockfd is not a valid descriptor."
        case EINVAL: reason = "The socket is already bound to an address or the addrlen is wrong, or the socket was not in the AF_UNIX family."
        case ENOTSOCK: reason = "sockfd is a descriptor for a file, not a socket."
        case EACCES: reason = "Search permission is denied on a component of the path prefix. (See also path_resolution(7).)"
        case EADDRNOTAVAIL: reason = "A nonexistent interface was requested or the requested address was not local."
        case EFAULT: reason = "addr points outside the user's accessible address space."
        case ELOOP: reason = "Too many symbolic links were encountered in resolving addr."
        case ENAMETOOLONG: reason = "addr is too long."
        case ENOENT: reason = "The file does not exist."
        case ENOMEM: reason = "Insufficient kernel memory was available."
        case ENOTDIR: reason = "A component of the path prefix is not a directory."
        case EROFS: reason = "The socket inode would reside on a read-only file system."
        default: reason = "unable to bind socket to \(ipAddress):\(port)"
        }
        throw Exception.fail(reason: reason)
    }
}
public extension TcpSocket {
    func connect(to ipAddress: String, with port: UInt16) throws {
        let result = Self.withAddress(ipAddress: ipAddress, port: port) { pointer, size -> Int32 in
            #if os(Linux)
            return Glibc.connect(self._socket, pointer, size)
            #else
            return Darwin.connect(self._socket, pointer, size)
            #endif
        }
        guard result == -1 else {
            return
        }
        let reason: String
        switch errno {
        case EACCES: reason = "For UNIX domain sockets, which are identified by pathname: Write permission is denied on the socket file, or search permission is denied for one of the directories in the path prefix.  (See also path_resolution(7).)"
        case EPERM: reason = "The user tried to connect to a broadcast address without having the socket broadcast flag enabled or the connection request failed because of a local firewall rule."
        case EADDRINUSE: reason = "Local address is already in use."
        case EADDRNOTAVAIL: reason = "(Internet domain sockets) The socket referred to by sockfd had not previously been bound to an address and, upon attempting to bind it to an ephemeral port, it was determined that all port numbers in the ephemeral port range are currently in use.  See the discussion of /proc/sys/net/ipv4/ip_local_port_range in ip(7)."
        case EAFNOSUPPORT: reason = "The passed address didn't have the correct address family in its sa_family field."
        case EAGAIN: reason = "For nonblocking UNIX domain sockets, the socket is nonblocking, and the connection cannot be completed immediately.  For other socket families, there are insufficient entries in the routing cache."
        case EALREADY: reason = "The socket is nonblocking and a previous connection attempt has not yet been completed."
        case EBADF: reason = "sockfd is not a valid open file descriptor."
        case ECONNREFUSED: reason = "A connect() on a stream socket found no one listening on the remote address."
        case EFAULT: reason = "The socket structure address is outside the user's address space."
        case EINPROGRESS: reason = "The socket is nonblocking and the connection cannot be completed immediately.  (UNIX domain sockets failed with EAGAIN instead.)  It is possible to select(2) or poll(2) for completion by selecting the socket for writing.  After select(2) indicates writability, use getsockopt(2) to read the SO_ERROR option at level SOL_SOCKET to determine whether connect() completed successfully (SO_ERROR is zero) or unsuccessfully (SO_ERROR is one of the usual error codes listed here, explaining the reason for the failure)."
        case EINTR: reason = "The system call was interrupted by a signal that was caught; see signal(7)."
        case EISCONN: reason = "The socket is already connected."
        case ENETUNREACH: reason = "Network is unreachable."
        case ENOTSOCK: reason = "The file descriptor sockfd does not refer to a socket."
        case EPROTOTYPE: reason = "The socket type does not support the requested communications protocol.  This error can occur, for example, on an attempt to connect a UNIX domain datagram socket to a stream socket."
        case ETIMEDOUT: reason = "Timeout while attempting connection.  The server may be too busy to accept new connections.  Note that for IP sockets the timeout may be very long when syncookies are enabled on the server."
        default: reason = "unable to connect to \(ipAddress):\(port)"
        }
        throw Exception.fail(reason: reason)
    }
}
public extension TcpSocket {
    func send(data: Data) throws {
        let result = data.withUnsafeBytes { buffer -> Int in
            #if os(Linux)
            return Glibc.send(self._socket, buffer.baseAddress, data.count, 0)
            #else
            return Darwin.send(self._socket, buffer.baseAddress, data.count, 0)
            #endif
        }
        guard result == -1 else {
            return
        }
        let reason: String
        switch errno {
        case EACCES: reason = "(For UNIX domain sockets, which are identified by pathname) Write permission is denied on the destination socket file, or search permission is denied for one of the directories the path prefix.  (See path_resolution(7).) (For UDP sockets) An attempt was made to send to a network/broadcast address as though it was a unicast address."
        case EAGAIN, EWOULDBLOCK: reason = "The socket is marked nonblocking and the requested operation would block.  POSIX.1-2001 allows either error to be returned for this case, and does not require these constants to have the same value, so a portable application should check for both possibilities."
        case EALREADY: reason = "Another Fast Open is in progress."
        case EBADF: reason = "sockfd is not a valid open file descriptor."
        case ECONNRESET: reason = "Connection reset by peer."
        case EDESTADDRREQ: reason = "The socket is not connection-mode, and no peer address is set."
        case EFAULT: reason = "An invalid user space address was specified for an argument."
        case EINTR: reason = "A signal occurred before any data was transmitted; see signal(7)."
        case EINVAL: reason = "Invalid argument passed."
        case EISCONN: reason = "The connection-mode socket was connected already but a recipient was specified.  (Now either this error is returned, or the recipient specification is ignored.)"
        case EMSGSIZE: reason = "The socket type requires that message be sent atomically, and the size of the message to be sent made this impossible."
        case ENOBUFS: reason = "The output queue for a network interface was full.  This generally indicates that the interface has stopped sending, but may be caused by transient congestion. (Normally, this does not occur in Linux.  Packets are just silently dropped when a device queue overflows.)"
        case ENOMEM: reason = "No memory available."
        case ENOTCONN: reason = "The socket is not connected, and no target has been given."
        case ENOTSOCK: reason = "The file descriptor sockfd does not refer to a socket."
        case EOPNOTSUPP: reason = "Some bit in the flags argument is inappropriate for the socket type."
        case EPIPE: reason = "The local end has been shut down on a connection oriented socket. In this case, the process will also receive a SIGPIPE unless MSG_NOSIGNAL is set."
        default: reason = "unable to send data"
        }
        throw Exception.fail(reason: reason)
    }
    func send(text: String) throws {
        guard let data = text.data(using: .utf8) else {
            throw Exception.fail(reason: "invalid string data")
        }
        try send(data: data)
    }
}
public extension TcpSocket {
    func recv(peekOnly: Bool = false, bufferSize: Int = 4096) throws -> Data {
        var data = Data(repeating: 0, count: bufferSize)
        let result = data.withUnsafeMutableBytes { pointer -> Int in
            guard let baseAddress = pointer.baseAddress?.bindMemory(to: UInt8.self, capacity: bufferSize) else {
                return -1
            }
            #if os(Linux)
            return Glibc.recv(self._socket, baseAddress, bufferSize, peekOnly ? Int32(MSG_PEEK) : 0)
            #else
            return Darwin.recv(self._socket, baseAddress, bufferSize, peekOnly ? MSG_PEEK : 0)
            #endif
        }
        guard result == -1 else {
            return data[0..<result]
        }
        let reason: String
        switch errno {
        case EAGAIN, EWOULDBLOCK: reason = "The socket is marked nonblocking and the receive operation would block, or a receive timeout had been set and the timeout expired before data was received.  POSIX.1 allows either error to be returned for this case, and does not require these constants to have the same value, so a portable application should check for both possibilities."
        case EBADF: reason = "The argument sockfd is an invalid file descriptor."
        case ECONNREFUSED: reason = "A remote host refused to allow the network connection (typically because it is not running the requested service)."
        case EFAULT: reason = "The receive buffer pointer(s) point outside the process's address space."
        case EINTR: reason = "The receive was interrupted by delivery of a signal before any data was available; see signal(7)."
        case EINVAL: reason = "Invalid argument passed."
        case ENOMEM: reason = "Could not allocate memory for recvmsg()."
        case ENOTCONN: reason = "The socket is associated with a connection-oriented protocol and has not been connected (see connect(2) and accept(2))."
        case ENOTSOCK: reason = "The file descriptor sockfd does not refer to a socket."
        default: reason = "unable to receive data"
        }
        throw Exception.fail(reason: reason)
    }
}
public extension TcpSocket {
    enum Exception: Error {
        case fault(reason: String, number: Int)
        static func fail(reason: String) -> Error {
            return Self.fault(reason: reason, number: Int(errno))
        }
    }
}
extension TcpSocket: Hashable {
    public static func == (lhs: TcpSocket, rhs: TcpSocket) -> Bool {
        return lhs.socketFD == rhs.socketFD
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(socketFD)
    }
}
extension TcpSocket: CustomStringConvertible {
    public var description: String {
        return "socket(\(socketFD)) -> \(ip):\(port)"
    }
}
