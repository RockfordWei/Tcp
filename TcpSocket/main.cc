//
//  main.cc
//  TcpSocket
//
//  Created by Rocky Wei on 2/15/23.
//

#include <iostream>
#include <string.h>
#include "tcpsocket.h"
using namespace std;

void echoSession(const void * tcpSocket) {
    if (!tcpSocket) return;
    auto client = (TcpSocket *)tcpSocket;
    size_t size = 0;
    auto request = client->request(&size);
    client->send(request, size);
    if (size > 0) {
        if (strstr((char*)request, "close")) client->terminate(); 
    }
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
