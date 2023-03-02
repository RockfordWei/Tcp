//
//  XCTestMainifests.swift
//
//
//  Created by Rocky Wei on 2023-02-08.
//

import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(JWTTests.allTests),
        testCase(TcpSocketTests.allTests)
    ]
}
#endif
