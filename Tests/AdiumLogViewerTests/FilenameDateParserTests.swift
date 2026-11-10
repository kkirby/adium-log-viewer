import XCTest
@testable import AdiumLogViewer

final class FilenameDateParserTests: XCTestCase {
    func testStandardFilenameDate() {
        let filename = "theirscreenname (2011-05-01T20.15.03-0400).chatlog"
        let date = FilenameDateParser.date(fromFilename: filename)
        XCTAssertNotNil(date)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -4 * 3600)!
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        XCTAssertEqual(comps.year, 2011)
        XCTAssertEqual(comps.month, 5)
        XCTAssertEqual(comps.day, 1)
        XCTAssertEqual(comps.hour, 20)
        XCTAssertEqual(comps.minute, 15)
        XCTAssertEqual(comps.second, 3)
    }

    func testLegacyPipeSeparatedDate() {
        // Very old Adium HTML logs used "(2005|05|07)" -- a bare date, no time or
        // timezone component at all -- instead of a full ISO8601 timestamp.
        let filename = "theirscreenname (2005|05|07).AdiumHTMLLog"
        let date = FilenameDateParser.date(fromFilename: filename)
        XCTAssertNotNil(date)

        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(comps.year, 2005)
        XCTAssertEqual(comps.month, 5)
        XCTAssertEqual(comps.day, 7)
    }

    func testLegacyDashSeparatedDateOnly() {
        // Later legacy HTML logs used "(2006-03-30)" -- still date-only, dashes
        // instead of pipes.
        let filename = "friend (2006-03-30).AdiumHTMLLog"
        let date = FilenameDateParser.date(fromFilename: filename)
        XCTAssertNotNil(date)

        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(comps.year, 2006)
        XCTAssertEqual(comps.month, 3)
        XCTAssertEqual(comps.day, 30)
    }

    func testMissingParenthesesReturnsNil() {
        XCTAssertNil(FilenameDateParser.date(fromFilename: "theirscreenname.chatlog"))
    }

    func testPositiveTimezoneOffset() {
        let filename = "friend (2020-01-15T09.30.00+0530).chatlog"
        let date = FilenameDateParser.date(fromFilename: filename)
        XCTAssertNotNil(date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 5 * 3600 + 30 * 60)!
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date!)
        XCTAssertEqual(comps.year, 2020)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 30)
    }

    func testLastParenthesizedGroupIsUsedWhenNameContainsParens() {
        // Contact display names can themselves contain parentheses; the parser
        // must use the LAST "(...)" group in the filename, matching AIChatLog.m.
        let filename = "Bob (work) (2011-05-01T20.15.03-0400).chatlog"
        let date = FilenameDateParser.date(fromFilename: filename)
        XCTAssertNotNil(date)
    }
}
