// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

// Minimal test harness.
//
// Each test is registered into `TestRegistry`. `main.swift` runs them all,
// records failures, and exits non-zero if any fail. Output mirrors what
// xunit / xctest produce so humans can scan PASS/FAIL at a glance.

import Foundation

public struct TestFailure: Error, CustomStringConvertible {
    public let message: String
    public let file: StaticString
    public let line: UInt
    public var description: String { "\(file):\(line): \(message)" }
}

public enum TestRegistry {
    public typealias Case = (name: String, run: () throws -> Void)
    public static var cases: [Case] = []
    public static func register(_ name: String, _ body: @escaping () throws -> Void) {
        cases.append((name, body))
    }
}

public func expect(_ cond: @autoclosure () -> Bool,
                   _ message: @autoclosure () -> String = "expectation failed",
                   file: StaticString = #file, line: UInt = #line) throws {
    if !cond() {
        throw TestFailure(message: message(), file: file, line: line)
    }
}

public func expectEqual<T: Equatable>(_ lhs: T, _ rhs: T,
                                      _ message: @autoclosure () -> String = "",
                                      file: StaticString = #file, line: UInt = #line) throws {
    if lhs != rhs {
        let msg = message().isEmpty
            ? "expected \(rhs) but got \(lhs)"
            : "\(message()) — expected \(rhs) but got \(lhs)"
        throw TestFailure(message: msg, file: file, line: line)
    }
}

public func expectNotEqual<T: Equatable>(_ lhs: T, _ rhs: T,
                                          _ message: @autoclosure () -> String = "",
                                          file: StaticString = #file, line: UInt = #line) throws {
    if lhs == rhs {
        let msg = message().isEmpty
            ? "expected != \(rhs) but values were equal"
            : "\(message()) — expected != \(rhs) but values were equal"
        throw TestFailure(message: msg, file: file, line: line)
    }
}

public func runAllTests() -> Int {
    var passed = 0
    var failed: [(String, Error)] = []
    let start = Date()
    print("Running \(TestRegistry.cases.count) tests…")
    for c in TestRegistry.cases {
        do {
            try c.run()
            passed += 1
            print("  \u{001B}[32mPASS\u{001B}[0m  \(c.name)")
        } catch {
            failed.append((c.name, error))
            print("  \u{001B}[31mFAIL\u{001B}[0m  \(c.name)\n        \(error)")
        }
    }
    let elapsed = String(format: "%.3fs", Date().timeIntervalSince(start))
    print("")
    if failed.isEmpty {
        print("\u{001B}[32m✓\u{001B}[0m \(passed) tests passed in \(elapsed)")
        return 0
    } else {
        print("\u{001B}[31m✗\u{001B}[0m \(failed.count) failed, \(passed) passed in \(elapsed)")
        return 1
    }
}
