import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SSLTests.allTests),
        testCase(TcpSocketTests.allTests)
    ]
}
#endif
