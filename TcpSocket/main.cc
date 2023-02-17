//
//  main.cc
//  TcpSocket
//
//  Created by Rocky Wei on 2/15/23.
//

#include <iostream>
#include "tcpsocket.h"
using namespace std;

vector<unsigned char> echoResponse(const vector <unsigned char> request) {
    return request;
}
int main(int argc, const char * argv[]) {
    try {
        auto server = TcpSocket();
        server.unblock();
        server.reuse();
        server.bind("127.0.0.1", 8080);
        server.listen();
        cout << "ready" << endl;
        server.run(1, &echoResponse);
    } catch (runtime_error exception) {
        cerr << exception.what() << endl;
    }
    return 0;
}
