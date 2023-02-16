//
//  tcpsocket.cc
//  TcpSocket
//
//  Created by Rocky Wei on 2/15/23.
//
#define szBUF 4096
#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <signal.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/fcntl.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include "tcpsocket.h"
TcpSocket::TcpSocket() {
    cerr << "socket()" << endl;
    _port = 0;
    _socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (-1 != _socket) return;
    switch (errno) {
        case EACCES: throw runtime_error("Permission to create a socket of the specified type and/or protocol is denied.");
        case EAFNOSUPPORT: throw runtime_error("The implementation does not support the specified address family.");
        case EINVAL: throw runtime_error("Unknown protocol, or protocol family not available.");
        case EMFILE: throw runtime_error("The per-process limit on the number of open file descriptors has been reached.");
        case ENFILE: throw runtime_error("The system-wide limit on the total number of open files has been reached.");
        case ENOBUFS:
        case ENOMEM: throw runtime_error("Insufficient memory is available.  The socket cannot be created until sufficient resources are freed.");
        case EPROTONOSUPPORT: throw runtime_error("The protocol type or the specified protocol is not supported within this domain.");
        default: throw runtime_error("Unknown error when socket(): " + to_string(errno));
    }
}
TcpSocket::TcpSocket(const int fd, const string ip, const int port) {
    cerr << "socket::copy()" << endl;
    if (fd < 1) throw runtime_error("invalid socket fd");
    _ip = ip;
    _port = port;
}
TcpSocket::~TcpSocket() {
    cerr << "close()" << endl;
    if (-1 == _socket) return;
    shutdown(_socket, SHUT_RDWR);
    close(_socket);
}
void TcpSocket::unblock() {
#ifdef __APPLE__
    cerr << "fcntl()" << endl;
    int result = ::fcntl(_socket, O_NONBLOCK);
#else
    cerr << "ioctl()" << endl;
    int result = ::ioctl(_socket, FIONBIO);
#endif
    if (-1 != result) return;
    switch (errno) {
        case EBADF: throw runtime_error("fd is not a valid file descriptor.");
        case EFAULT: throw runtime_error("argp references an inaccessible memory area.");
        case EINVAL: throw runtime_error("request or argp is not valid.");
        case ENOTTY: throw runtime_error("fd is not associated with a character special device.");
        default: throw runtime_error("Unknown error when fcntl(): " + to_string(errno));
    }
}
void TcpSocket::reuse() {
    cerr << "setsockopt()" << endl;
    int option = 1;
    int result = ::setsockopt(_socket, SOL_SOCKET, SO_REUSEADDR, &option, sizeof(int));
    if (-1 != result) return;
    switch (errno) {
        case EBADF: throw runtime_error("The argument sockfd is not a valid descriptor.");
        case EFAULT: throw runtime_error("The address pointed to by optval is not in a valid part of the process address space. For getsockopt(), this error may also be returned if optlen is not in a valid part of the process address space.");
        case EINVAL: throw runtime_error("optlen invalid in setsockopt(). In some cases this error can also occur for an invalid value in optval (e.g., for the IP_ADD_MEMBERSHIP option described in ip(7)).");
        case ENOPROTOOPT: throw runtime_error("The option is unknown at the level indicated.");
        case ENOTSOCK: throw runtime_error("The argument sockfd is a file, not a socket.");
        default: throw runtime_error("Unknown error when setsockopt(): " + to_string(errno));
    }
}
void TcpSocket::bind(const string ip, const int port) {
    cerr << "bind()" << endl;
    _ip = ip;
    _port = port;
    struct sockaddr_in host;
    memset(&host, 0, sizeof(host));
    host.sin_family = AF_INET;
    host.sin_addr.s_addr = inet_addr(ip.c_str());
    host.sin_port = htons(port);
    socklen_t sizeSocket = sizeof(host);
    int result = ::bind(_socket, (const struct sockaddr *)&host, sizeSocket);
    if (-1 != result) return;
    switch(errno) {
        case EACCES: throw runtime_error("The address is protected, and the user is not the superuser.");
        case EADDRINUSE: throw runtime_error("The given address is already in use.");
        case EBADF: throw runtime_error("sockfd is not a valid file descriptor.");
        case EINVAL: throw runtime_error("The socket is already bound to an address.");
        case ENOTSOCK: throw runtime_error("The file descriptor sockfd does not refer to a socket.");
        case EADDRNOTAVAIL: throw runtime_error("A nonexistent interface was requested or the requested address was not local.");
        case EFAULT: throw runtime_error("addr points outside the user's accessible address space.");
        case ELOOP: throw runtime_error("Too many symbolic links were encountered in resolving addr.");
        case ENAMETOOLONG: throw runtime_error("addr is too long.");
        case ENOENT: throw runtime_error("A component in the directory prefix of the socket pathname does not exist.");
        case ENOMEM: throw runtime_error("Insufficient kernel memory was available.");
        case ENOTDIR: throw runtime_error("A component of the path prefix is not a directory.");
        case EROFS: throw runtime_error("The socket inode would reside on a read-only filesystem.");
        default: throw runtime_error("Unknown error when bind(): " + to_string(errno));
    }
}
void TcpSocket::listen() {
    cerr << "listen()" << endl;
    int result = ::listen(_socket, SOMAXCONN);
    if (-1 != result) return;
    switch (errno) {
        case EADDRINUSE: throw runtime_error("Another socket is already listening on the same port.");
        case EBADF: throw runtime_error("The argument sockfd is not a valid file descriptor.");
        case ENOTSOCK: throw runtime_error("The file descriptor sockfd does not refer to a socket.");
        case EOPNOTSUPP: throw runtime_error("The socket is not of a type that supports the listen() operation.");
        default: throw runtime_error("Unknown error when listen(): " + to_string(errno));
    }
}
TcpSocket TcpSocket::accept() {
    cerr << "accept()" << endl;
    struct sockaddr_in address;
    socklen_t size = sizeof(address);
    int fd = ::accept(_socket, (struct sockaddr *)&address, &size);
    if (fd > 0) {
        return TcpSocket(fd, inet_ntoa(address.sin_addr), htons(address.sin_port));
    }
    switch (errno) {
        case EAGAIN: throw runtime_error("The socket is marked nonblocking and no connections are present to be accepted.  POSIX.1-2001 and POSIX.1-2008 allow either error to be returned for this case, and do not require these constants to have the same value, so a portable application should check for both possibilities.");
        case EBADF: throw runtime_error("sockfd is not an open file descriptor.");
        case ECONNABORTED: throw runtime_error("A connection has been aborted.");
        case EFAULT: throw runtime_error("The addr argument is not in a writable part of the user address space.");
        case EINTR: throw runtime_error("The system call was interrupted by a signal that was caught before a valid connection arrived; see signal(7).");
        case EINVAL: throw runtime_error("Socket is not listening for connections, or addrlen is invalid (e.g., is negative).");
        case EMFILE: throw runtime_error("The per-process limit on the number of open file descriptors has been reached.");
        case ENFILE: throw runtime_error("The system-wide limit on the total number of open files has been reached.");
        case ENOBUFS:
        case ENOMEM: throw runtime_error("Not enough free memory. This often means that the memory allocation is limited by the socket buffer limits, not by the system memory.");
        case ENOTSOCK: throw runtime_error("The file descriptor sockfd does not refer to a socket.");
        case EOPNOTSUPP: throw runtime_error("The referenced socket is not of type SOCK_STREAM.");
        case EPERM: throw runtime_error("Firewall rules forbid connection.");
        case EPROTO: throw runtime_error("Protocol error.");
        default: throw runtime_error("Unknown error when accept(): " + to_string(errno));
    }
}
void TcpSocket::send(const void * data, const size_t size) {
    cerr << "send()" << endl;
    if (!data || size < 1) throw runtime_error("invalid data buffer");
    ssize_t result = ::send(_socket, data, size, 0);
    if (-1 != result) return;
    switch (errno) {
        case EACCES: throw runtime_error("(For UNIX domain sockets, which are identified by pathname) Write permission is denied on the destination socket file, or search permission is denied for one of the directories the path prefix.  (See path_resolution(7).) (For UDP sockets) An attempt was made to send to a network/broadcast address as though it was a unicast address.");
        case EAGAIN: throw runtime_error("The socket is marked nonblocking and the requested operation would block.  POSIX.1-2001 allows either error to be returned for this case, and does not require these constants to have the same value, so a portable application should check for both possibilities.");
        case EALREADY: throw runtime_error("Another Fast Open is in progress.");
        case EBADF: throw runtime_error("sockfd is not a valid open file descriptor.");
        case ECONNRESET: throw runtime_error("Connection reset by peer.");
        case EDESTADDRREQ: throw runtime_error("The socket is not connection-mode, and no peer address is set.");
        case EFAULT: throw runtime_error("An invalid user space address was specified for an argument.");
        case EINTR: throw runtime_error("A signal occurred before any data was transmitted; see signal(7).");
        case EINVAL: throw runtime_error("Invalid argument passed.");
        case EISCONN: throw runtime_error("The connection-mode socket was connected already but a recipient was specified.  (Now either this error is returned, or the recipient specification is ignored.)");
        case EMSGSIZE: throw runtime_error("The socket type requires that message be sent atomically, and the size of the message to be sent made this impossible.");
        case ENOBUFS: throw runtime_error("The output queue for a network interface was full. This generally indicates that the interface has stopped sending, but may be caused by transient congestion. (Normally, this does not occur in Linux.  Packets are just silently dropped when a device queue overflows.)");
        case ENOMEM: throw runtime_error("No memory available.");
        case ENOTCONN: throw runtime_error("The socket is not connected, and no target has been given.");
        case ENOTSOCK: throw runtime_error("The file descriptor sockfd does not refer to a socket.");
        case EOPNOTSUPP: throw runtime_error("Some bit in the flags argument is inappropriate for the socket type.");
        case EPIPE: throw runtime_error("The local end has been shut down on a connection oriented socket.  In this case, the process will also receive a SIGPIPE unless MSG_NOSIGNAL is set.");
        default: throw runtime_error("Unknown error when send(): " + to_string(errno));
    }
}
void TcpSocket::send(const vector<unsigned char> data) {
    send(data.data(), data.size());
}
void TcpSocket::send(const string content) {
    send(content.c_str(), content.size());
}
size_t TcpSocket::recv(bool peek) {
    unsigned char * buffer = (unsigned char *)malloc(szBUF);
    memset(buffer, 0, szBUF);
    size_t size = ::recv(_socket, buffer, szBUF, peek ? MSG_PEEK : 0);
    if (size > 0) {
        for(size_t i = 0; i < size; i++) {
            _buffer.push_back(buffer[i]);
        }
    }
    free(buffer);
    if (size == 0) ::shutdown(_socket, SHUT_RD);
    if (size >= 0) return size;
    switch (errno) {
        case EAGAIN: throw runtime_error("The socket is marked nonblocking and the receive operation would block, or a receive timeout had been set and the timeout expired before data was received.  POSIX.1 allows either error to be returned for this case, and does not require these constants to have the same value, so a portable application should check for both possibilities.");
        case EBADF: throw runtime_error("The argument sockfd is an invalid file descriptor.");
        case ECONNREFUSED: throw runtime_error("A remote host refused to allow the network connection (typically because it is not running the requested service).");
        case EFAULT: throw runtime_error("The receive buffer pointer(s) point outside the process's address space.");
        case EINTR: throw runtime_error("The receive was interrupted by delivery of a signal before any data was available; see signal(7).");
        case EINVAL: throw runtime_error("Invalid argument passed.");
        case ENOMEM: throw runtime_error("Could not allocate memory for recvmsg().");
        case ENOTCONN: throw runtime_error("The socket is associated with a connection-oriented protocol and has not been connected (see connect(2) and accept(2)).");
        case ENOTSOCK: throw runtime_error("The file descriptor sockfd does not refer to a socket.");
        default: throw runtime_error("Unknown error when recv(): " + to_string(errno));
    }
}
void TcpSocket::setDelegate(const TcpServerSocketDelegate *delegate) {
    _delegate = (TcpServerSocketDelegate *)delegate;
}
void TcpSocket::select(const int timeoutSeconds) {
    fd_set readfds, errorfds;
    FD_ZERO(&readfds);
    FD_ZERO(&errorfds);
    FD_SET(_socket, &readfds);
    FD_SET(_socket, &errorfds);
    int largest = _socket;
    for(auto client: _clients) {
        int sck = client._socket;
        if (sck > largest) largest = sck;
        FD_SET(sck, &readfds);
        FD_SET(sck, &errorfds);
    }
    largest++;
#if __APPLE__
    if (largest > FD_SETSIZE) largest = FD_SETSIZE;
#endif
    struct timeval timeout;
    timeout.tv_sec = timeoutSeconds;
    timeout.tv_usec = 0;
    int result = ::select(largest, &readfds, NULL, &errorfds, &timeout);
    if (0 == result) return;
    if (-1 == result) {
        switch (errno) {
            case EBADF: throw runtime_error("An invalid file descriptor was given in one of the sets. (Perhaps a file descriptor that was already closed, or one on which an error has occurred.)  However, see BUGS.");
            case EINTR: throw runtime_error("A signal was caught; see signal(7).");
            case EINVAL: throw runtime_error("nfds is negative or exceeds the RLIMIT_NOFILE resource limit (see getrlimit(2)).");
            case ENOMEM: throw runtime_error("Unable to allocate memory for internal tables.");
            default: throw runtime_error("Unknown error when select(): " + to_string(errno));
        }
    }
    if (FD_ISSET(_socket, &errorfds)) {
        throw runtime_error("server socket failure");
    }
    if (FD_ISSET(_socket, &readfds)) {
        try {
            auto client = accept();
            _clients.push_back(client);
        } catch (runtime_error exception) {
            cerr << "accept() failed: " << exception.what() << endl;
        }
    }
    for(auto client: _clients) {
        int sck = client._socket;
        if (FD_ISSET(sck, &errorfds)) {
            _clients.remove(client);
        } else if (FD_ISSET(sck, &readfds)) {
            try {
                size_t result = client.recv(false);
                if (0 == result) {
                    if (_delegate) {
                        auto response = _delegate->respond(client._buffer);
                        if (response) {
                            if (response->size() > 0) {
                                client.send(*response);
                            } else {
                                // pending new data if giving an empty data
                            }
                        } else {
                            _clients.remove(client);
                        }
                    }
                } else {
                    // pending more data until reading completed
                }
            } catch(runtime_error exception) {
                _clients.remove(client);
            }
        }
    }
}
bool TcpSocket::equal(const TcpSocket& to) const {
    return _socket == to._socket;
}
bool operator == (const TcpSocket& me, const TcpSocket& other) {
    return me.equal(other);
}
