//
//  HttpServer.swift
//  
//
//  Created by Rocky Wei on 2/23/23.
//

import Foundation

public struct HttpRoute: Hashable {
    public let api: String
    public let method: HttpRequest.Method
    public let handler: (_ request: HttpRequest) throws -> HttpResponse?
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.api == rhs.api && lhs.method == rhs.method
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(method)
        hasher.combine(api)
    }
}

public class HttpServer: TcpSocket, TcpSocketDelegate {
    internal let _routes: Set<HttpRoute>
    
    public var webroot: String?
    public init(port: UInt16, routes: [HttpRoute]) throws {
        _routes = Set<HttpRoute>(routes)
        try super.init()
        self.delegate = self
        try bind(port: port)
        try listen()
        serve()
    }
    public func onDataArrival(tcpSocket: TcpSocket) {
        var httpRequest: HttpRequest?
        do {
            let requestData = try tcpSocket.recv()
            guard !requestData.isEmpty else {
                return
            }
            NSLog("\(requestData.count) bytes received")
            tcpSocket.buffer.append(requestData)
            guard let _request = try HttpRequest(request: tcpSocket.buffer) else {
                return
            }
            httpRequest = _request
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
        guard let request = httpRequest else {
            return
        }
        var responseData: Data?
        var responseFile: String?
        var responseSize: Int?
        do {
            if let route = _routes.first(where: { request.method == $0.method && request.uri.raw.hasPrefix($0.api) }) {
                let resp = try route.handler(request)
                responseData = try resp?.encode()
                responseFile = nil
                responseSize = nil
            } else if let localPath = self.webroot,
                      request.method == .GET {
                let path = "\(localPath)\(request.uri.raw)"
                let response = HttpResponse(path: path)
                responseData = try? response.encode()
                responseFile = response.contentLength > 0 ? path : nil
                responseSize = response.contentLength
            } else {
                responseData = nil
                responseFile = nil
                responseSize = nil
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
        if let path = responseFile, let size = responseSize {
            try? tcpSocket.send(path: path, size: size)
        }
        tcpSocket.shutdown()
        tcpSocket.close()
        tcpSocket.live = false
    }
}
