// 28/10: the Claude tab's reading of a session: which of the four stages it's in (Read, Edit, Test, Done),
// the elapsed time, the changed lines to show, and how strong the green glow is after it finishes.
// Foundation only, tested in tests/.
import Foundation

enum ClaudeFasi {
    /// Read, Edit, Test, Done.
    static let quante = 4

    /// A command that runs tests, judged by its text.
    static func isTest(_ label: String) -> Bool {
        let l = label.lowercased()
        return ["test", "pytest", "jest", "vitest", "rspec", "xcodebuild", "ctest", "check"].contains { l.contains($0) }
    }

    /// The stage one step belongs to: reading and searching 0, editing 1, running tests 2. Other commands: none.
    static func fase(kind: String, label: String) -> Int? {
        switch kind {
        case "READ", "FIND", "WEB", "PLAN", "AGENT": return 0
        case "EDIT": return 1
        case "RUN": return isTest(label) ? 2 : nil
        default: return nil
        }
    }

    /// How far the session got: the furthest stage of any step, 3 once it's done. 0 with no steps yet.
    static func raggiunta(_ steps: [(kind: String, label: String)], finita: Bool) -> Int {
        if finita { return 3 }
        return steps.compactMap { fase(kind: $0.kind, label: $0.label) }.max() ?? 0
    }

    /// "0:04", "12:05", "1:02:03".
    static func tempo(_ secondi: Double) -> String {
        let s = max(0, Int(secondi))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    /// The last changed lines of a diff ("+ x", "- y"), without the file headers, at most `max`.
    static func righe(_ diff: [String], max: Int = 2) -> [String] {
        let cambiate = diff.filter { ($0.hasPrefix("+") || $0.hasPrefix("-")) && !$0.hasPrefix("+++") && !$0.hasPrefix("---") }
        return Array(cambiate.suffix(max))
    }

    /// The green after "done": full for 4 seconds, then fading out over 26 more. 0 when it isn't done.
    static func verde(finitaDa secondi: Double?) -> Double {
        guard let s = secondi, s >= 0 else { return 0 }
        return s <= 4 ? 1 : Swift.max(0, 1 - (s - 4) / 26)
    }
}
