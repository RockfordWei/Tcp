//
//  TcpContext.swift
//  
//
//  Created by Rocky Wei on 6/30/23.
//

#if os(Linux)
import Glibc
#else
import Darwin
#endif
import Foundation

public enum TcpContext: String {
    case option
    case bind
    case connect
    case sendData
    case sendFile
    case receive
    case listen
    case accept
    case poll
    
    static func fault(reason: String, code: Int = 0) -> Error {
        return NSError(domain: reason, code: code)
    }
    static func assert(result: Int32, context: Self) throws {
        guard let error = lookupError(result: result, context: context) else {
            return
        }
        throw error
    }
    internal static func lookupError(result: Int32, context: Self) -> Error? {
        guard result == -1 else {
            return nil
        }
        let userInfo: [String: Any] = ["context": context]
        let bufferSize = 1024
        var buffer = [CChar](repeating: 0, count: bufferSize)
        _ = strerror_r(errno, &buffer, bufferSize)
        let domain = String(cString: buffer)
        return NSError(domain: domain, code: Int(errno), userInfo: userInfo)
    }
}
