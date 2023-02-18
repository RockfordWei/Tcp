//
//  main.cc
//  TcpSocket
//
//  Created by Rocky Wei on 2/15/23.
//

#include "tcpsocket.h"
using namespace std;

class ClientSocket: TcpSocket {
public:
    void echo();
};
void ClientSocket::echo() {
    lock_guard<mutex> guard(*_shared);
    auto request = _buffer.data();
    if (!request) return;
    send(request, _buffer.size());
    if (strstr((char*)request, "close")) {
        terminate();
    }
}
void echoSession(TcpSocket * tcpSocket) {
    auto client = (ClientSocket *)tcpSocket;
    client->echo();
}
int main(int argc, const char * argv[]) {
    try {
        auto server = TcpSocket();
        server.setup(&cerr);
        server.unblock();
        server.reuse();
        server.bind("0.0.0.0", 8080);
        server.listen();
        cout << "ready" << endl;
        server.run(1, &echoSession);
    } catch (runtime_error exception) {
        cerr << exception.what() << endl;
    }
    return 0;
}
