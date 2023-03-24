//
//  JWTTests.swift
//
//
//  Created by Rocky Wei on 2023-03-01.
//

import Foundation
@testable import JWT
import XCTest

final class JWTTests: XCTestCase {
    func getShaData(input: Data, algo: DigestAlgorithm = .SHA256) throws -> Data {
        let process = Process()
        let stdInp = Pipe()
        let stdOut = Pipe()
        let stdErr = Pipe()
        let algorithm = algo.rawValue.replacingOccurrences(of: "SHA", with: "")
        process.standardOutput = stdOut
        process.standardError = stdErr
        process.arguments = ["-a", algorithm]
        process.executableURL = URL(string: "file:///usr/bin/shasum")
        process.standardInput = stdInp
        stdInp.fileHandleForWriting.write(input)
        try stdInp.fileHandleForWriting.close()
        try process.run()
        process.waitUntilExit()
        let errData = stdErr.fileHandleForReading.readDataToEndOfFile()
        try stdErr.fileHandleForReading.close()
        if !errData.isEmpty {
            if let errText = String(data: errData, encoding: .utf8) {
                throw NSError(domain: errText, code: 0, userInfo: nil)
            } else {
                throw NSError(domain: "error", code: 0, userInfo: ["data": errData])
            }
        }
        let data = stdOut.fileHandleForReading.readDataToEndOfFile()
        try stdOut.fileHandleForReading.close()
        return data
    }
    func getHmacText(input: String, secret: String, algo: DigestAlgorithm = .SHA256) throws -> String {
        let process = Process()
        let stdInp = Pipe()
        let stdOut = Pipe()
        let stdErr = Pipe()
        let algorithm = "-" + algo.rawValue.lowercased()
        process.standardOutput = stdOut
        process.standardError = stdErr
        process.arguments = ["dgst", algorithm, "-hmac", secret]
        process.executableURL = URL(string: "file:///usr/bin/openssl")
        process.standardInput = stdInp
        let inputData = try XCTUnwrap(input.data(using: .utf8))
        stdInp.fileHandleForWriting.write(inputData)
        try stdInp.fileHandleForWriting.close()
        try process.run()
        process.waitUntilExit()
        let errData = stdErr.fileHandleForReading.readDataToEndOfFile()
        try stdErr.fileHandleForReading.close()
        if !errData.isEmpty {
            if let errText = String(data: errData, encoding: .utf8) {
                throw NSError(domain: errText, code: 0, userInfo: nil)
            } else {
                throw NSError(domain: "error", code: 0, userInfo: ["data": errData])
            }
        }
        let data = stdOut.fileHandleForReading.readDataToEndOfFile()
        try stdOut.fileHandleForReading.close()
        return try XCTUnwrap(String(data: data, encoding: .utf8)).trimmed
    }
    func getShaHex(input: Data, algo: DigestAlgorithm) throws -> String {
        let data = try getShaData(input: input, algo: algo)
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "unexpected output from shasum command", code: 0, userInfo: nil)
        }
        return text
    }
    func _testShaRandom(index: Int, algo: DigestAlgorithm) throws -> XCTestExpectation {
        let size = Int.random(in: 0..<65536)
        let exp = XCTestExpectation(description: "testRandom\(index)")
        DispatchQueue.global(qos: .background).async {
            let bytes: [UInt8] = (0..<size).map { _ -> UInt8 in
                return UInt8.random(in: 0..<255)
            }
            let source = Data(bytes)
            do {
                try self._testSha(source: source, algo: algo)
            } catch {
                XCTFail("random test #\(index) with \(size) bytes failed: \(error)")
            }
            exp.fulfill()
        }
        return exp
    }
    func _testSha(source: Data, algo: DigestAlgorithm) throws {
        let hash = try source.digest(algorithm: algo).hex
        let wanted = try getShaHex(input: source, algo: algo)
        NSLog("generated: \(hash)")
        NSLog("expecting: \(wanted)")
        XCTAssertTrue(wanted.hasPrefix(hash))
        var stream: [Int32] = [0, 0]
        let bytes: [UInt8] = source.map { $0 }
        let streamed = try bytes.withUnsafeBytes { pointer -> String in
            #if os(Linux)
            Glibc.pipe(&stream)
            Glibc.write(stream[1], pointer.baseAddress, source.count)
            Glibc.close(stream[1])
            #else
            Darwin.pipe(&stream)
            Darwin.write(stream[1], pointer.baseAddress, source.count)
            Darwin.close(stream[1])
            #endif
            let sha = try DigestAlgorithm.hash(streamReaderFileNumber: stream[0], algorithm: algo)
            return sha.hex
        }
        NSLog("streaming: \(streamed)")
        XCTAssertEqual(hash, streamed)
    }
    func testSha() throws {
        let expectations = (0..<20).compactMap { try? self._testShaRandom(index: $0, algo: $0 % 2 == 0 ? .SHA256 : .SHA512) }
        wait(for: expectations, timeout: 60)
    }
    func testRotateRight() throws {
        let x = UInt32(0x12345678)
        XCTAssertEqual(x.rotateRight(by: 7), UInt32(0xf02468ac))
    }
    func testMajor() throws {
        let x: UInt32 = 0x12345678
        let y: UInt32 = 0x90abcdef
        let z: UInt32 = 0x11223344
        XCTAssertEqual(UInt32.major(x: x, y: y, z: z), UInt32(0x1022576c))
    }
    func testChoose() throws {
        let x: UInt32 = 0x12345678
        let y: UInt32 = 0x90abcdef
        let z: UInt32 = 0x11223344
        XCTAssertEqual(UInt32.choose(x: x, y: y, z: z), UInt32(0x1122656c))
    }
    func testSigma0() throws {
        let x: UInt32 = 0x12345678
        XCTAssertEqual(UInt32(0xe7fce6ee), x.sigma0)
    }
    func testSigma1() throws {
        let x: UInt32 = 0x12345678
        XCTAssertEqual(UInt32(0xa1f78649), x.sigma1)
    }
    func testGamma0() throws {
        let x: UInt32 = 0x12345678
        XCTAssertEqual(UInt32(0x66146474), x.gamma0)
    }
    func testGamma1() throws {
        let x: UInt32 = 0x12345678
        XCTAssertEqual(UInt32(0x3561abda), x.gamma1)
    }
    func _testHmac(message: String, secret: String, algorithm: DigestAlgorithm) throws {
        NSLog("testing HMAC \(algorithm) with \(message.count) bytes input and \(secret.count) bytes secret")
        let actual = try HMAC.digestHex(message: message, by: secret, using: algorithm)
        let wanted = try getHmacText(input: message, secret: secret, algo: algorithm)
        XCTAssert(wanted.contains(actual))
    }
    func _testHmacRandom(messageSeed: String, secretSeed: String, round: Int, algorithm: DigestAlgorithm) -> XCTestExpectation {
        let exp = expectation(description: "hmac-\(algorithm)-random-\(round)")
        DispatchQueue.global(qos: .background).async {
            var message = ""
            var secret = ""
            for _ in 1..<round {
                message += messageSeed
                secret += secretSeed
            }
            do {
                try self._testHmac(message: message, secret: secret, algorithm: algorithm)
            } catch {
                XCTFail("\(exp.description) failed")
            }
            exp.fulfill()
        }
        return exp
    }
    func testHMAC() throws {
        let message = "hello\n"
        let secret = "abcd1234"
        let expectations = (0..<20).map { index -> XCTestExpectation in
            let algo: DigestAlgorithm = index % 2 == 0 ? .SHA256 : .SHA512
            let round = Int.random(in: 1..<256)
            return self._testHmacRandom(messageSeed: message, secretSeed: secret, round: round, algorithm: algo)
        }
        wait(for: expectations, timeout: 60)
    }
    func _testJWT(algorithm: String) throws {
        let secret = "abcd1234"
        let claim = JWTExamplePayload(email: "guest@nowhere.unknown", issuer: "authority", timestamp: Date())
        let token = try JWT.encode(claims: claim, secret: secret, algorithm: algorithm)
        let parts = token.split(separator: ".")
        XCTAssertEqual(parts.count, 3)
        NSLog("JWT \(algorithm) token: \(token)")
        let payload: JWTExamplePayload = try JWT.decode(token: token, secret: secret)
        XCTAssertEqual(payload, claim)
        let compromised = [String(parts[0]), String(parts[1]), "1234abcd"].joined(separator: ".")
        do {
            let attemp: JWTExamplePayload = try JWT.decode(token: compromised, secret: secret)
            XCTFail("token is compromised: \(attemp)")
        } catch {
            XCTAssertEqual((error as NSError).domain, "signature is not matched")
        }
    }
    func testJWT() throws {
        try _testJWT(algorithm: "HS256")
        try _testJWT(algorithm: "HS512")
    }
    static var allTests = [
        ("testSha", testSha),
        ("testRotateRight", testRotateRight),
        ("testMajor", testMajor),
        ("testChoose", testChoose),
        ("testSigma0", testSigma0),
        ("testSigma1", testSigma1),
        ("testGamma0", testGamma0),
        ("testGamma1", testGamma1),
        ("testHMAC", testHMAC),
        ("testJWT", testJWT)
    ]
}

struct JWTExamplePayload: Codable {
    let email: String
    let issuer: String
    let timestamp: Date
}

extension JWTExamplePayload: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.email == rhs.email && lhs.issuer == rhs.issuer && lhs.timestamp == rhs.timestamp
    }
}
