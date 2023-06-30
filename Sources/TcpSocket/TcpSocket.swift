//
//  TcpSocket.swift
//
//
//  Created by Rocky Wei on 2023-02-08.
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif
import Foundation

public protocol TcpSocketDelegate: AnyObject {
    func onDataArrival(tcpSocket: TcpSocket)
}

open class TcpSocket {
    internal let _socket: Int32
    public enum ShutdownMethod {
        case read
        case write
        case both
    }
    public var socketFD: Int {
        return Int(_socket)
    }
    internal var _ip: String = "0.0.0.0"
    internal var _port: UInt16 = 0
    public var timeoutMilliseconds: Int32 = 100
    public var ip: String {
        return _ip
    }
    public var port: UInt16 {
        return _port
    }
    public var live = true
    public var delegate: TcpSocketDelegate?
    internal var clients: Set<TcpSocket> = []
    public var buffer = Data()
    public init(originalSocket: Int32, ipAddress: String, port: UInt16) {
        _socket = originalSocket
        _ip = ipAddress
        _port = port
    }
    public convenience init(originalSocket: Int32, address: sockaddr) {
        var addr = address
        let (ipAddress, port): (String, UInt16) = withUnsafePointer(to: &addr) { baseAddress -> (String, UInt16) in
            let placeholder = sockaddr_in()
            let size = MemoryLayout.size(ofValue: placeholder)
            return baseAddress.withMemoryRebound(to: sockaddr_in.self, capacity: size) { pointer -> (String, UInt16) in
                let ip = String(cString: inet_ntoa(pointer.pointee.sin_addr))
                let port = pointer.pointee.sin_port.byteSwapped
                return (ip, port)
            }
        }
        self.init(originalSocket: originalSocket, ipAddress: ipAddress, port: port)
    }
    public init() throws {
        #if os(Linux)
        _socket = socket(AF_INET, 1, Int32(IPPROTO_TCP))
        #else
        _socket = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        guard _socket > 0 else {
            throw TcpContext.fault(reason: "unable to create socket", code: Int(errno))
        }
        var option: Int32 = 1
        let result = setsockopt(_socket, SOL_SOCKET, SO_REUSEADDR, &option, socklen_t(MemoryLayout.size(ofValue: option)))
        try TcpContext.assert(result: result, context: .option)
    }
    public func shutdown(method: ShutdownMethod = .both) {
        let value: Int32
        switch method {
        case .read: value = Int32(SHUT_RD)
        case .write: value = Int32(SHUT_WR)
        default: value = Int32(SHUT_RDWR)
        }
        #if os(Linux)
        Glibc.shutdown(_socket, value)
        #else
        Darwin.shutdown(_socket, value)
        #endif
    }
    public func close() {
        #if os(Linux)
        Glibc.close(_socket)
        #else
        Darwin.close(_socket)
        #endif
    }
}

public extension TcpSocket {
    static func withAddress<Result>(ipAddress: String = "0.0.0.0", port: UInt16, perform operation: @escaping (UnsafePointer<sockaddr>, socklen_t) -> Result) -> Result {
        var host = sockaddr_in()
        host.sin_family = sa_family_t(AF_INET)
        host.sin_port = in_port_t(port.byteSwapped)
        host.sin_addr = in_addr(s_addr: inet_addr(ipAddress))
        let size = socklen_t(MemoryLayout.size(ofValue: host))
        return withUnsafePointer(to: &host) { baseAddress -> Result in
            return baseAddress.withMemoryRebound(to: sockaddr.self, capacity: Int(size)) { pointer -> Result in
                return operation(pointer, size)
            }
        }
    }
}

public extension TcpSocket {
    func bind(ipAddress: String = "0.0.0.0", port: UInt16) throws {
        self._ip = ipAddress
        self._port = port
        let result = Self.withAddress(ipAddress: ipAddress, port: port) { pointer, size -> Int32 in
            #if os(Linux)
            return Glibc.bind(self._socket, pointer, size)
            #else
            return Darwin.bind(self._socket, pointer, size)
            #endif
        }
        try TcpContext.assert(result: result, context: .bind)
    }
}

public extension TcpSocket {
    func connect(to ipAddress: String = "0.0.0.0", with port: UInt16) throws {
        let result = Self.withAddress(ipAddress: ipAddress, port: port) { pointer, size -> Int32 in
            #if os(Linux)
            return Glibc.connect(self._socket, pointer, size)
            #else
            return Darwin.connect(self._socket, pointer, size)
            #endif
        }
        try TcpContext.assert(result: result, context: .connect)
    }
    @available(macOS 10.15, *)
    func asyncConnect(to ipAddress: String = "0.0.0.0", with port: UInt16) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    try self.connect(to: ipAddress, with: port)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

public extension TcpSocket {
    func send(data: Data) throws {
        let result = data.withUnsafeBytes { buffer -> Int in
            #if os(Linux)
            return Glibc.send(self._socket, buffer.baseAddress, data.count, 0)
            #else
            return Darwin.send(self._socket, buffer.baseAddress, data.count, 0)
            #endif
        }
        try TcpContext.assert(result: Int32(result), context: .sendData)
    }
    func send(text: String) throws {
        guard let data = text.data(using: .utf8) else {
            throw TcpContext.fault(reason: "invalid string data")
        }
        try send(data: data)
    }
    func send(path: String, size: Int) throws {
        guard let file = fopen(path, "rb") else {
            throw TcpContext.fault(reason: "unable to open file at \(path)")
        }
        let fd = fileno(file)
        defer {
            fclose(file)
        }
        #if os(Linux)
            let result = Int32(sendfile(self._socket, fd, nil, size))
        #else
            let offset = off_t(0)
            var remain = off_t(size)
            let result = sendfile(fd, self._socket, offset, &remain, nil, 0)
        #endif
        try TcpContext.assert(result: result, context: .sendFile)
    }
}

public extension TcpSocket {
    func recv(peekOnly: Bool = false, bufferSize: Int = 65536) throws -> Data {
        var data = Data(repeating: 0, count: bufferSize)
        let result = data.withUnsafeMutableBytes { pointer -> Int in
            guard let baseAddress = pointer.baseAddress?.bindMemory(to: UInt8.self, capacity: bufferSize) else {
                return -1
            }
            #if os(Linux)
            return Glibc.recv(self._socket, baseAddress, bufferSize, peekOnly ? Int32(MSG_PEEK) : 0)
            #else
            return Darwin.recv(self._socket, baseAddress, bufferSize, peekOnly ? MSG_PEEK : 0)
            #endif
        }
        try TcpContext.assert(result: Int32(result), context: .receive)
        return data[0..<result]
    }
    @available(macOS 10.15, *)
    func receive(bufferSize: Int = 4096, until: @escaping (Data) -> Bool) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    var data = Data()
                    repeat {
                        let partial = try self.recv(bufferSize: bufferSize)
                        data.append(partial)
                    } while !until(data)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension TcpSocket: Hashable {
    public static func == (lhs: TcpSocket, rhs: TcpSocket) -> Bool {
        return lhs.socketFD == rhs.socketFD
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(socketFD)
    }
}

extension TcpSocket: CustomStringConvertible {
    public var description: String {
        return "socket(\(socketFD)) -> \(ip):\(port)"
    }
}
