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
class TcpServerSocketDelegate {
public:
    virtual vector<unsigned char> * respond(const vector <unsigned char> request);
};
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
    void setDelegate(const TcpServerSocketDelegate * delegate);
    void select(const int timeoutSeconds);
    bool equal(const TcpSocket& to) const;
protected:
    int _socket;
    string _ip;
    int _port;
    list<TcpSocket> _clients;
    vector<unsigned char> _buffer;
    TcpServerSocketDelegate * _delegate;
};
bool operator == (const TcpSocket& me, const TcpSocket& other);
#endif /* tcpsocket_h */
