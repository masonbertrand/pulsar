// 28/10: the pure parts of the Communications, Meetings and Notion tabs. Foundation only, tested in tests/.
import Foundation

enum CommsLogic {
    /// A Dock badge as a number: "3" → 3, "99+" → 99, a dot or anything else non-numeric → 1 (it means "something new").
    /// No badge → nil.
    static func conteggio(_ badge: String?) -> Int? {
        guard let b = badge?.trimmingCharacters(in: .whitespaces), !b.isEmpty else { return nil }
        let cifre = b.filter(\.isNumber)
        return Int(cifre) ?? 1
    }

    /// Apps with something unread, most first; ties by name.
    static func ordina(_ app: [(nome: String, badge: String?)]) -> [(nome: String, conteggio: Int)] {
        app.compactMap { a in conteggio(a.badge).map { (nome: a.nome, conteggio: $0) } }
            .sorted { $0.conteggio != $1.conteggio ? $0.conteggio > $1.conteggio : $0.nome < $1.nome }
    }

    /// The messaging apps the tab offers even when they have nothing unread.
    static let note = ["Slack", "Lark", "Feishu", "Messages", "Mail", "WhatsApp", "Discord", "Microsoft Teams", "Telegram", "Signal"]
}

enum AgendaLogic {
    struct Voce: Equatable { var start: Date; var end: Date; var allDay: Bool }

    /// What's left of today: events not yet over, all-day ones first, then by start time.
    static func resto(_ eventi: [Voce], ora: Date, cal: Calendar = .current) -> [Int] {
        let fine = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: ora))!
        return eventi.indices
            .filter { eventi[$0].end > ora && eventi[$0].start < fine }
            .sorted { a, b in
                let x = eventi[a], y = eventi[b]
                if x.allDay != y.allDay { return x.allDay }
                return x.start < y.start
            }
    }
}

enum NotionLinks {
    /// A Notion link as one the Notion app opens directly (notion://…); nil if it isn't a Notion link.
    static func app(_ link: String) -> URL? {
        guard let u = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)), let host = u.host?.lowercased(),
              host == "notion.so" || host.hasSuffix(".notion.so") || host.hasSuffix(".notion.site") else { return nil }
        var c = URLComponents(url: u, resolvingAgainstBaseURL: false)!
        c.scheme = "notion"
        return c.url
    }

    /// A name for a pinned page when none is given: the title part of the link, without the id at the end.
    static func nome(_ link: String) -> String {
        guard let ultimo = URL(string: link)?.lastPathComponent, !ultimo.isEmpty, ultimo != "/" else { return "Notion" }
        var parti = ultimo.split(separator: "-")
        if let id = parti.last, id.count == 32, id.allSatisfy(\.isHexDigit) { parti.removeLast() }
        let s = parti.joined(separator: " ")
        return s.isEmpty ? "Notion" : s
    }
}

/// 29/10: the order of the island's tabs, which the user can change and save.
enum OrdineSchede {
    /// The saved order ("casa,claude,…"), keeping only known tabs once each; tabs added in later versions go at the end.
    static func leggi(_ salvato: String?, tutte: [String]) -> [String] {
        var visti = Set<String>()
        let noti = (salvato ?? "").split(separator: ",").map(String.init).filter { tutte.contains($0) && visti.insert($0).inserted }
        return noti + tutte.filter { !visti.contains($0) }
    }

    /// `id` moved to position `a` (clamped).
    static func sposta(_ ordine: [String], _ id: String, a: Int) -> [String] {
        guard let i = ordine.firstIndex(of: id) else { return ordine }
        var o = ordine
        o.remove(at: i)
        o.insert(id, at: min(max(a, 0), o.count))
        return o
    }
}
