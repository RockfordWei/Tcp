//
//  tcpsocket.h
//  TcpSocket
//
//  Created by Rocky Wei on 2/15/23.
//

#ifndef tcpsocket_h
#define tcpsocket_h
#define szIP 16
class TcpSocket {
public:
    TcpSocket();
    TcpSocket(const int fd, const char * ip, const int port);
    ~TcpSocket();
    void unblock();
    void reuse();
    void bind(const char * ip, const int port);
    void listen();
    TcpSocket accept();
private:
    int _socket;
    char _ip[szIP];
    int _port;
};

#endif /* tcpsocket_h */
