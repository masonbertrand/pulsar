// When an automatic update may relaunch Pulsar, and the one-line note shown after it. Foundation only, tested in tests/.
import Foundation

enum UpdateTiming {
    /// How long before a meeting Pulsar stops relaunching itself.
    static let primaRiunione: TimeInterval = 10 * 60

    /// Not while Claude waits for an answer, not while the island is open in front of you,
    /// not from 10 minutes before a meeting until it ends.
    static func canRestart(claudeWaiting: Bool, islandOpen: Bool, meeting: (start: Date, end: Date)?, now: Date) -> Bool {
        if claudeWaiting || islandOpen { return false }
        if let m = meeting, now >= m.start.addingTimeInterval(-primaRiunione), now < m.end { return false }
        return true
    }

    /// The first line of the release notes, without HTML, at most `max` characters.
    static func note(_ description: String?, max: Int = 60) -> String {
        guard var s = description else { return "" }
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (e, c) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#x27;", "'"), ("&#39;", "'"), ("&amp;", "&")] {
            s = s.replacingOccurrences(of: e, with: c)
        }
        let line = s.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
        return line.count > max ? String(line.prefix(max - 1)).trimmingCharacters(in: .whitespaces) + "…" : line
    }
}
