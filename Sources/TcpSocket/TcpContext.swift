//
//  TcpContext.swift
//  
//
//  Created by Rocky Wei on 6/30/23.
//

import Foundation

public enum TcpContext: String {
    case option
    case bind
    case connect
    case sendData
    case sendFile
    case receive
    case listen
    case accept
    case poll
    
    static func fault(reason: String, code: Int = 0) -> Error {
        return NSError(domain: reason, code: code)
    }
    static func assert(result: Int32, context: Self) throws {
        guard let error = lookupError(result: result, context: context) else {
            return
        }
        throw error
    }
    internal static func lookupError(result: Int32, context: Self) -> Error? {
        guard result == -1 else {
            return nil
        }
        let userInfo: [String: Any] = ["context": context]
        let error: NSError
        if let messages = errorMessages[context],
           let domain = messages[errno] {
            error = NSError(domain: domain, code: Int(errno), userInfo: userInfo)
        } else {
            error = NSError(domain: "Unkown error", code: Int(errno), userInfo: userInfo)
        }
        return error
    }
    internal static let errorMessages: [Self: [Int32: String]] = [
        .option: [
            EBADF: "The argument sockfd is not a valid descriptor.",
            EFAULT: "The address pointed to by optval is not in a valid part of the process address space. For getsockopt(), this error may also be returned if optlen is not in a valid part of the process address space.",
            EINVAL: "optlen invalid in setsockopt(). In some cases this error can also occur for an invalid value in optval (e.g., for the IP_ADD_MEMBERSHIP option described in ip(7)).",
            ENOPROTOOPT: "The option is unknown at the level indicated.",
            ENOTSOCK: "The argument sockfd is a file, not a socket."
        ],
        .bind: [
            EACCES: "The address is protected, and the user is not the superuser.",
            EADDRINUSE: "The given address is already in use.",
            EBADF: "sockfd is not a valid descriptor.",
            EINVAL: "The socket is already bound to an address or the addrlen is wrong, or the socket was not in the AF_UNIX family.",
            ENOTSOCK: "sockfd is a descriptor for a file, not a socket.",
            EADDRNOTAVAIL: "A nonexistent interface was requested or the requested address was not local.",
            EFAULT: "addr points outside the user's accessible address space.",
            ELOOP: "Too many symbolic links were encountered in resolving addr.",
            ENAMETOOLONG: "addr is too long.",
            ENOENT: "The file does not exist.",
            ENOMEM: "Insufficient kernel memory was available.",
            ENOTDIR: "A component of the path prefix is not a directory.",
            EROFS: "The socket inode would reside on a read-only file system."
        ],
        .connect: [
            EACCES: "For UNIX domain sockets, which are identified by pathname: Write permission is denied on the socket file, or search permission is denied for one of the directories in the path prefix.  (See also path_resolution(7).)",
            EPERM: "The user tried to connect to a broadcast address without having the socket broadcast flag enabled or the connection request failed because of a local firewall rule.",
            EADDRINUSE: "Local address is already in use.",
            EADDRNOTAVAIL: "(Internet domain sockets) The socket referred to by sockfd had not previously been bound to an address and, upon attempting to bind it to an ephemeral port, it was determined that all port numbers in the ephemeral port range are currently in use.  See the discussion of /proc/sys/net/ipv4/ip_local_port_range in ip(7).",
            EAFNOSUPPORT: "The passed address didn't have the correct address family in its sa_family field.",
            EAGAIN: "For nonblocking UNIX domain sockets, the socket is nonblocking, and the connection cannot be completed immediately.  For other socket families, there are insufficient entries in the routing cache.",
            EALREADY: "The socket is nonblocking and a previous connection attempt has not yet been completed.",
            EBADF: "sockfd is not a valid open file descriptor.",
            ECONNREFUSED: "A connect() on a stream socket found no one listening on the remote address.",
            EFAULT: "The socket structure address is outside the user's address space.",
            EINPROGRESS: "The socket is nonblocking and the connection cannot be completed immediately.  (UNIX domain sockets failed with EAGAIN instead.)  It is possible to select(2) or poll(2) for completion by selecting the socket for writing.  After select(2) indicates writability, use getsockopt(2) to read the SO_ERROR option at level SOL_SOCKET to determine whether connect() completed successfully (SO_ERROR is zero) or unsuccessfully (SO_ERROR is one of the usual error codes listed here, explaining the reason for the failure).",
            EINTR: "The system call was interrupted by a signal that was caught; see signal(7).",
            EISCONN: "The socket is already connected.",
            ENETUNREACH: "Network is unreachable.",
            ENOTSOCK: "The file descriptor sockfd does not refer to a socket.",
            EPROTOTYPE: "The socket type does not support the requested communications protocol.  This error can occur, for example, on an attempt to connect a UNIX domain datagram socket to a stream socket.",
            ETIMEDOUT: "Timeout while attempting connection.  The server may be too busy to accept new connections.  Note that for IP sockets the timeout may be very long when syncookies are enabled on the server.",
        ],
        .sendData: [
            EACCES: "(For UNIX domain sockets, which are identified by pathname) Write permission is denied on the destination socket file, or search permission is denied for one of the directories the path prefix.  (See path_resolution(7).) (For UDP sockets) An attempt was made to send to a network/broadcast address as though it was a unicast address.",
            EWOULDBLOCK: "The socket is marked nonblocking and the requested operation would block.  POSIX.1-2001 allows either error to be returned for this case, and does not require these constants to have the same value, so a portable application should check for both possibilities.",
            EALREADY: "Another Fast Open is in progress.",
            EBADF: "sockfd is not a valid open file descriptor.",
            ECONNRESET: "Connection reset by peer.",
            EDESTADDRREQ: "The socket is not connection-mode, and no peer address is set.",
            EFAULT: "An invalid user space address was specified for an argument.",
            EINTR: "A signal occurred before any data was transmitted; see signal(7).",
            EINVAL: "Invalid argument passed.",
            EISCONN: "The connection-mode socket was connected already but a recipient was specified.  (Now either this error is returned, or the recipient specification is ignored.)",
            EMSGSIZE: "The socket type requires that message be sent atomically, and the size of the message to be sent made this impossible.",
            ENOBUFS: "The output queue for a network interface was full.  This generally indicates that the interface has stopped sending, but may be caused by transient congestion. (Normally, this does not occur in Linux.  Packets are just silently dropped when a device queue overflows.)",
            ENOMEM: "No memory available.",
            ENOTCONN: "The socket is not connected, and no target has been given.",
            ENOTSOCK: "The file descriptor sockfd does not refer to a socket.",
            EOPNOTSUPP: "Some bit in the flags argument is inappropriate for the socket type.",
            EPIPE: "The local end has been shut down on a connection oriented socket. In this case, the process will also receive a SIGPIPE unless MSG_NOSIGNAL is set."
        ],
        .sendFile: [
            EAGAIN: "The socket is marked for non-blocking I/O and not all data was sent due to the socket buffer being full.  If specified, the number of bytes successfully sent will be returned in *len.",
            EBADF: "The s argument is not a valid socket descriptor.",
            EFAULT: "An invalid address was specified for an argument.",
            EINTR: "A signal interrupted sendfile() before it could be completed.  If specified, the number of bytes success-fully successfully fully sent will be returned in *len.",
            EINVAL: "The offset argument is negative, or the len argument is NULL, or the flags argument is not set to 0.",
            EIO: "An error occurred while reading from fd.",
            ENOTCONN: "The s argument points to an unconnected socket.",
            ENOTSOCK: "The s argument is not a socket.",
            EOPNOTSUPP: "The file system for descriptor fd does not support sendfile().",
            EPIPE: "The socket peer has closed the connection."
        ],
        .receive: [
            EWOULDBLOCK: "The socket is marked nonblocking and the receive operation would block, or a receive timeout had been set and the timeout expired before data was received.  POSIX.1 allows either error to be returned for this case, and does not require these constants to have the same value, so a portable application should check for both possibilities.",
            EBADF: "The argument sockfd is an invalid file descriptor.",
            ECONNREFUSED: "A remote host refused to allow the network connection (typically because it is not running the requested service).",
            EFAULT: "The receive buffer pointer(s) point outside the process's address space.",
            EINTR: "The receive was interrupted by delivery of a signal before any data was available; see signal(7).",
            EINVAL: "Invalid argument passed.",
            ENOMEM: "Could not allocate memory for recvmsg().",
            ENOTCONN: "The socket is associated with a connection-oriented protocol and has not been connected (see connect(2) and accept(2)).",
            ENOTSOCK: "The file descriptor sockfd does not refer to a socket."
        ],
        .listen: [
            EADDRINUSE: "Another socket is already listening on the same port.",
            EBADF: "The argument sockfd is not a valid file descriptor.",
            ENOTSOCK: "The file descriptor sockfd does not refer to a socket.",
            EOPNOTSUPP: "The socket is not of a type that supports the listen() operation."
        ],
        .accept: [
            EAGAIN: "The socket is marked nonblocking and no connections are present to be accepted.  POSIX.1-2001 and POSIX.1-2008 allow either error to be returned for this case, and do not require these constants to have the same value, so a portable application should check for both possibilities.",
            EBADF: "sockfd is not an open file descriptor.",
            ECONNABORTED: "A connection has been aborted.",
            EFAULT: "The addr argument is not in a writable part of the user address space.",
            EINTR: "The system call was interrupted by a signal that was caught before a valid connection arrived; see signal(7).",
            EINVAL: "Socket is not listening for connections, or addrlen is invalid (e.g., is negative), or (accept4()) invalid value in flags.",
            EMFILE: "The per-process limit on the number of open file descriptors has been reached.",
            ENFILE: "The system-wide limit on the total number of open files has been reached.",
            ENOBUFS: "Not enough free memory.  This often means that the memory allocation is limited by the socket buffer limits, not by the system memory.",
            ENOMEM: "Not enough free memory.  This often means that the memory allocation is limited by the socket buffer limits, not by the system memory.",
            ENOTSOCK: "The file descriptor sockfd does not refer to a socket.",
            EOPNOTSUPP: "The referenced socket is not of type SOCK_STREAM.",
            EPERM: "Firewall rules forbid connection.",
            EPROTO: "Protocol error."
        ],
        .poll: [
            EAGAIN: "Allocation of internal data structures fails.  A sub-sequent subsequent sequent request may succeed.",
            EFAULT: "Fds points outside the process's allocated address space.",
            EINTR: "A signal is delivered before the time limit expires and before any of the selected events occurs.",
            EINVAL: "The nfds argument is greater than OPEN_MAX or the timeout argument is less than -1."
        ]
    ]
}
