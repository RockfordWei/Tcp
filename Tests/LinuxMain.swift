import XCTest
import SSLTests
import TcpSocketTests

var tests = [XCTestCaseEntry]()
tests += SSLTests.allTests()
tests += TcpSocketTests.allTests()
XCTMain(tests)
