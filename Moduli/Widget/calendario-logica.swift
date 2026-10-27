// Which event the Event tile shows, and how it names the day. Foundation only, tested in tests/.
import Foundation

enum ProssimoEvento {
    struct Voce: Equatable { var start: Date; var end: Date; var allDay: Bool }

    /// How far ahead the tile looks when today is empty.
    static let giorni = 7

    /// The first day (from today) that has something left: on that day the first timed event, or the first
    /// all-day one if it has only those. An event already under way counts for today. Nil if nothing in range.
    static func scegli(_ eventi: [Voce], ora: Date, cal: Calendar = .current) -> Int? {
        let oggi = cal.startOfDay(for: ora)
        func giorno(_ e: Voce) -> Date { max(cal.startOfDay(for: e.start), oggi) }
        let validi = eventi.indices.filter { eventi[$0].end > ora }
        guard let primo = validi.map({ giorno(eventi[$0]) }).min() else { return nil }
        let quelGiorno = validi.filter { giorno(eventi[$0]) == primo }
        let conOrario = quelGiorno.filter { !eventi[$0].allDay }.min { eventi[$0].start < eventi[$1].start }
        return conOrario ?? quelGiorno.first
    }

    /// Nil for today (the tile already shows today's date), then "Tomorrow", then the weekday name.
    static func giorno(_ start: Date, ora: Date, inglese: Bool, cal: Calendar = .current) -> String? {
        let d = cal.dateComponents([.day], from: cal.startOfDay(for: ora), to: cal.startOfDay(for: start)).day ?? 0
        if d <= 0 { return nil }
        if d == 1 { return inglese ? "Tomorrow" : "Domani" }
        let f = DateFormatter()
        f.locale = Locale(identifier: inglese ? "en_US" : "it_IT")
        f.calendar = cal
        f.dateFormat = "EEEE"
        let s = f.string(from: start)
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}
