// A tiny test harness: no XCTest, so the tests build with plain swiftc like the app.
import Foundation

var failures = 0
var checks = 0

func check(_ ok: @autoclosure () -> Bool, _ what: String, file: String = #fileID, line: Int = #line) {
    checks += 1
    if !ok() { failures += 1; print("FAIL \(file):\(line)  \(what)") }
}

func equal<T: Equatable>(_ a: T, _ b: T, _ what: String = "", file: String = #fileID, line: Int = #line) {
    check(a == b, "\(what) expected \(b), got \(a)", file: file, line: line)
}

/// A fixed date for tests: 2026-10-27 at the given hour and minute, local time.
func at(_ h: Int, _ m: Int = 0, day: Int = 27) -> Date {
    Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h, minute: m))!
}
