//
//  tcpsocket.cc
//  TcpSocket
//
//  Created by Rocky Wei on 2/15/23.
//

#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <signal.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/fcntl.h>
#include <sys/socket.h>
#include <unistd.h>
#include <iostream>
#include <list>
#include <set>
#include <string>
using namespace std;

#include "tcpsocket.h"

TcpSocket::TcpSocket() {
    cerr << "socket()" << endl;
    memset(_ip, 0, szIP);
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
TcpSocket::TcpSocket(const int fd, const char * ip, const int port) {
    cerr << "socket::copy()" << endl;
    if (fd < 1) throw runtime_error("invalid socket fd");
    if (ip) strcpy(_ip, ip);
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
        default: throw runtime_error("Unknown error when setsockopt()");
    }
}
void TcpSocket::bind(const char * ip, const int port) {
    cerr << "bind()" << endl;
    if (ip) strcpy(_ip, ip);
    _port = port;
    struct sockaddr_in host;
    memset(&host, 0, sizeof(host));
    host.sin_family = AF_INET;
    host.sin_addr.s_addr = ip ? inet_addr(ip) : INADDR_ANY;
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
        default: throw runtime_error("Unknown error when bind()");
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
        default: throw runtime_error("Unknown error when listen()");
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
        case ENOMEM: throw runtime_error("Not enough free memory.  This often means that the memory allocation is limited by the socket buffer limits, not by the system memory.");
        case ENOTSOCK: throw runtime_error("The file descriptor sockfd does not refer to a socket.");
        case EOPNOTSUPP: throw runtime_error("The referenced socket is not of type SOCK_STREAM.");
        case EPERM: throw runtime_error("Firewall rules forbid connection.");
        case EPROTO: throw runtime_error("Protocol error.");
        default: throw runtime_error("Unknown error when accept()");
    }
}
