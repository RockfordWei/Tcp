//
//  tcpsocket.h
//  TcpSocket
//
//  Created by Rocky Wei on 2/15/23.
//

#ifndef tcpsocket_h
#define tcpsocket_h
#include <iostream>
#include <list>
#include <string>
#include <vector>
using namespace std;
typedef vector<unsigned char> (*TcpSessionHandler)(const vector<unsigned char>);
class TcpSocket {
public:
    TcpSocket();
    TcpSocket(const int fd, const string ip, const int port);
    ~TcpSocket();
    void unblock();
    void reuse();
    void bind(const string ip, const int port);
    void listen();
    TcpSocket accept();
    void send(const void * data, const size_t size);
    void send(const vector<unsigned char> data);
    void send(const string content);
    size_t recv(bool peek);
    void select(const int timeoutSeconds, TcpSessionHandler handler);
    bool equal(const TcpSocket& to) const;
    void run(const int timeoutSeconds, TcpSessionHandler handler);
    void terminate();
protected:
    int _socket;
    string _ip;
    int _port;
    list<TcpSocket> _clients;
    vector<unsigned char> _buffer;
    bool _live;
};
bool operator == (const TcpSocket& me, const TcpSocket& other);
#endif /* tcpsocket_h */
