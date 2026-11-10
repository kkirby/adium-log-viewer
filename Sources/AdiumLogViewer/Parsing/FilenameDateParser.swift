import Foundation

/// Ports `AIChatLog.m`'s `dateFromFileName()`. The filename's parenthesized date
/// uses a DOT as the time separator (`2011-05-01T20.15.03-0400`), which is distinct
/// from the ISO-8601 `time` attribute inside the XML itself (which uses colons).
/// Very old logs used `2005|05|07`-style dates with `|` in place of `-`.
enum FilenameDateParser {
    static func date(fromFilename filename: String) -> Date? {
        guard let openParen = filename.range(of: "(", options: .backwards) else {
            return nil
        }
        let afterOpen = filename[openParen.upperBound...]
        guard let closeParen = afterOpen.range(of: ")") else {
            return nil
        }
        var dateString = String(afterOpen[afterOpen.startIndex..<closeParen.lowerBound])
        dateString = dateString.replacingOccurrences(of: "|", with: "-")
        return parseISO8601DotSeparated(dateString)
    }

    /// Parses `YYYY-MM-DD'T'HH.mm.ssZZZZZ` (dot time separator) without relying on
    /// `ISO8601DateFormatter`, which only accepts colon-separated times.
    private static func parseISO8601DotSeparated(_ string: String) -> Date? {
        // Split off the timezone suffix (+HHMM / -HHMM / Z) first, since it may
        // itself contain no further separators we need to touch.
        var datePart = string
        var timeZoneSeconds = 0

        if let tzRange = string.range(of: "Z", options: .backwards), tzRange.upperBound == string.endIndex {
            datePart = String(string[string.startIndex..<tzRange.lowerBound])
        } else if let signIndex = findTimeZoneSignIndex(string) {
            let tzString = String(string[signIndex...])
            datePart = String(string[string.startIndex..<signIndex])
            timeZoneSeconds = parseTimeZoneOffset(tzString) ?? 0
        }

        // datePart is now "YYYY-MM-DDTHH.mm.ss", or just "YYYY-MM-DD" for legacy
        // HTML logs, whose filenames never included a time component at all
        // (e.g. "Bob (2006-03-30).AdiumHTMLLog" / "Bob (2006|03|30).AdiumHTMLLog").
        let comps = datePart.split(separator: "T")
        guard comps.count == 2 else {
            return parseDateOnly(datePart)
        }
        let dateComps = comps[0].split(separator: "-")
        let timeComps = comps[1].split(separator: ".")
        guard dateComps.count == 3, timeComps.count == 3,
              let year = Int(dateComps[0]), let month = Int(dateComps[1]), let day = Int(dateComps[2]),
              let hour = Int(timeComps[0]), let minute = Int(timeComps[1]), let second = Int(timeComps[2]) else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: timeZoneSeconds) ?? TimeZone(identifier: "UTC")!
        var dc = DateComponents()
        dc.year = year; dc.month = month; dc.day = day
        dc.hour = hour; dc.minute = minute; dc.second = second
        return calendar.date(from: dc)
    }

    /// Parses a bare "YYYY-MM-DD" with no time/timezone component, at midnight in
    /// the current calendar's default time zone (the filename carries no offset).
    private static func parseDateOnly(_ string: String) -> Date? {
        let dateComps = string.split(separator: "-")
        guard dateComps.count == 3,
              let year = Int(dateComps[0]), let month = Int(dateComps[1]), let day = Int(dateComps[2]) else {
            return nil
        }
        var dc = DateComponents()
        dc.year = year; dc.month = month; dc.day = day
        return Calendar(identifier: .gregorian).date(from: dc)
    }

    private static func findTimeZoneSignIndex(_ string: String) -> String.Index? {
        // Look for a "+" or "-" that appears after the "T" (to avoid matching the
        // date's own "-" separators), scanning from the end.
        guard let tIndex = string.firstIndex(of: "T") else { return nil }
        let searchRange = string.index(after: tIndex)..<string.endIndex
        return string.range(of: "+", options: .backwards, range: searchRange)?.lowerBound
            ?? string.range(of: "-", options: .backwards, range: searchRange)?.lowerBound
    }

    private static func parseTimeZoneOffset(_ tz: String) -> Int? {
        guard let sign = tz.first else { return nil }
        let digits = tz.dropFirst()
        guard digits.count == 4, let hh = Int(digits.prefix(2)), let mm = Int(digits.suffix(2)) else {
            return nil
        }
        let total = hh * 3600 + mm * 60
        return sign == "-" ? -total : total
    }
}
