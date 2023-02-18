//
//  tcpsocket.h
//  TcpSocket
//
//  Created by Rocky Wei on 2/15/23.
//

#ifndef tcpsocket_h
#define tcpsocket_h
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
#include <future>
#include <iostream>
#include <mutex>
#include <set>
#include <string>
#include <thread>
#include <vector>
using namespace std;
class TcpSocket {
public:
    typedef void (*TcpClientSessionHandler)(TcpSocket *);
    TcpSocket();
    TcpSocket(const int fd, const string ip, const int port);
    ~TcpSocket();
    void shutdown(const int method);
    void close();
    void unblock();
    void reuse();
    void bind(const string ip, const int port);
    void listen();
    TcpSocket * accept();
    void send(const void * data, const size_t size);
    void send(const vector<unsigned char> data);
    void send(const string content);
    size_t recv(bool peek);
    void * request(size_t * size);
    void select(const int timeoutSeconds, TcpClientSessionHandler handler);
    bool equal(const TcpSocket& to) const;
    void run(const int timeoutSeconds, TcpClientSessionHandler handler);
    void terminate();
    void setup(ostream * errorLog);
    void log(const string message);
    void clean();
protected:
    int _socket;
    ostream * _errorLog;
    string _ip;
    int _port;
    set<TcpSocket *> _clients;
    vector<unsigned char> _buffer;
    bool _live;
    mutex * _shared;
};
bool operator == (const TcpSocket& me, const TcpSocket& other);
#endif /* tcpsocket_h */
