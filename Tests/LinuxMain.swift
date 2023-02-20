import XCTest

import TcpSocketTests

var tests = [XCTestCaseEntry]()
tests += TcpSocketTests.allTests()
XCTMain(tests)
