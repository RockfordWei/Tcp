//
//  HttpServer.swift
//  
//
//  Created by Rocky Wei on 2/23/23.
//

import Foundation

public protocol HttpServerDelegate {
    func onSession(request: HttpRequest) throws -> HttpResponse?
}

public class HttpServer: TcpSocket, TcpSocketDelegate {
    internal let sessionDelegate: HttpServerDelegate
    
    public init(port: UInt16, delegate: HttpServerDelegate) throws {
        sessionDelegate = delegate
        try super.init()
        self.delegate = self
        try bind(port: port)
        try listen()
        serve()
    }
    public func onDataArrival(tcpSocket: TcpSocket) {
        var request: HttpRequest?
        do {
            let requestData = try tcpSocket.recv()
            guard !requestData.isEmpty else {
                return
            }
            request = try HttpRequest(request: requestData)
        } catch {
            let nserror = error as NSError
            let response = HttpResponse(content: "Bad Request: \(error)")
            response.code = nserror.code
            if let respData = try? response.encode() {
                try? tcpSocket.send(data: respData)
            }
            tcpSocket.shutdown()
            tcpSocket.close()
            tcpSocket.live = false
        }
        guard let request = request else { return }
        var responseData: Data?
        do {
            if let response = try sessionDelegate.onSession(request: request) {
                responseData = try response.encode()
            } else {
                responseData = nil
            }
        } catch {
            let nserror = error as NSError
            let response = HttpResponse(content: "Bad Request: \(error)")
            response.code = nserror.code
            responseData = try? response.encode()
        }
        if let data = responseData {
            try? tcpSocket.send(data: data)
        }
        tcpSocket.shutdown()
        tcpSocket.close()
        tcpSocket.live = false
    }
}
