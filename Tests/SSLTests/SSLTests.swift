import Foundation
@testable import SSL
import XCTest

final class SSLTests: XCTestCase {
    func _testSha256(text: String, wanted: String) throws {
        let source = try XCTUnwrap(text.data(using: .ascii))
        let hash = source.sha256
        XCTAssertEqual(hash.hex, wanted)
    }
    func testSha256() throws {
        try _testSha256(text: "hello\n", wanted: "5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03")
        try _testSha256(text: "Hello, world!\n", wanted: "d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5")
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
    static var allTests = [
        ("testRotateRight", testRotateRight),
        ("testChoose", testChoose),
        ("testMajor", testMajor),
        ("testSha256", testSha256),
        ("testSigma0", testSigma0),
        ("testSigma1", testSigma1),
        ("testGamma0", testGamma0),
        ("testGamma1", testGamma1),
    ]
}
