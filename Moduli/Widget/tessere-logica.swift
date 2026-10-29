// 29/10: pure parts of the second batch of tiles: Bluetooth batteries, stock quotes, habit streaks, countdowns,
// VPN list, focus stats. Foundation only, tested in tests/.
import Foundation

enum BatterieBT {
    struct Voce: Equatable { var nome: String; var livelli: [String: Int] }   // "Left" / "Right" / "Case" / "" → %

    /// From `system_profiler SPBluetoothDataType`: connected devices that report a battery level.
    static func leggi(_ testo: String) -> [Voce] {
        var out: [Voce] = []
        var nome: String?
        var livelli: [String: Int] = [:]
        var connessi = false
        func chiudi() { if let n = nome, !livelli.isEmpty { out.append(Voce(nome: n, livelli: livelli)) }; nome = nil; livelli = [:] }
        for riga in testo.split(separator: "\n", omittingEmptySubsequences: false) {
            let r = String(riga)
            let t = r.trimmingCharacters(in: .whitespaces)
            let rientro = r.prefix { $0 == " " }.count
            if t == "Connected:" { connessi = true; continue }
            if t == "Not Connected:" { chiudi(); connessi = false; continue }
            guard connessi else { continue }
            if t.hasSuffix(":"), !t.contains(" Level"), rientro >= 8, rientro <= 10 { chiudi(); nome = String(t.dropLast()); continue }
            if let i = t.range(of: "Battery Level:") {
                let chi = t[..<i.lowerBound].trimmingCharacters(in: .whitespaces)
                let v = Int(t[i.upperBound...].filter(\.isNumber))
                if let v { livelli[chi] = v }
            }
        }
        chiudi()
        return out
    }
}

enum Quote {
    struct Prezzo: Equatable { var simbolo: String; var prezzo: Double; var variazione: Double }   // variazione in %

    /// Yahoo Finance's chart endpoint: the last price and the change from the previous close.
    static func leggi(_ d: Data) -> Prezzo? {
        guard let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let r = ((j["chart"] as? [String: Any])?["result"] as? [[String: Any]])?.first,
              let m = r["meta"] as? [String: Any], let s = m["symbol"] as? String,
              let p = (m["regularMarketPrice"] as? Double) else { return nil }
        let prima = (m["chartPreviousClose"] as? Double) ?? (m["previousClose"] as? Double) ?? p
        return Prezzo(simbolo: s, prezzo: p, variazione: prima == 0 ? 0 : (p - prima) / prima * 100)
    }

    static func testo(_ p: Double) -> String { p >= 1000 ? String(format: "%.0f", p) : p >= 1 ? String(format: "%.2f", p) : String(format: "%.4f", p) }
}

enum Abitudini {
    /// Days in a row ending today (or yesterday, if today isn't done yet). Days are "yyyy-MM-dd".
    static func serie(_ giorni: Set<String>, oggi: Date, cal: Calendar = .current) -> Int {
        let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone; f.dateFormat = "yyyy-MM-dd"
        var d = cal.startOfDay(for: oggi)
        if !giorni.contains(f.string(from: d)) { d = cal.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while giorni.contains(f.string(from: d)) { n += 1; d = cal.date(byAdding: .day, value: -1, to: d)! }
        return n
    }

    static func giorno(_ d: Date, cal: Calendar = .current) -> String {
        let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}

enum ContoAllaRovescia {
    /// Whole days from today to the date (0 on the day, negative after).
    static func giorni(a: Date, da: Date, cal: Calendar = .current) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: da), to: cal.startOfDay(for: a)).day ?? 0
    }
}

enum VPN {
    struct Voce: Equatable { var nome: String; var connessa: Bool }

    /// From `scutil --nc list`: lines like `* (Connected)  ABC… VPN (com.apple…) "Work VPN"  [IPSec]`.
    static func leggi(_ testo: String) -> [Voce] {
        testo.split(separator: "\n").compactMap { r in
            guard let a = r.firstIndex(of: "\""), let b = r[r.index(after: a)...].firstIndex(of: "\"") else { return nil }
            return Voce(nome: String(r[r.index(after: a)..<b]), connessa: r.contains("(Connected)"))
        }
    }
}

enum StatisticheFocus {
    /// Minutes of focus for each of the last `n` days, oldest first, from "yyyy-MM-dd" → minutes.
    static func settimana(_ registro: [String: Int], oggi: Date, n: Int = 7, cal: Calendar = .current) -> [Int] {
        (0..<n).reversed().map { k in
            registro[Abitudini.giorno(cal.date(byAdding: .day, value: -k, to: oggi)!, cal: cal)] ?? 0
        }
    }
}

/// 29/10, the user: "colours like green for good, red for bad". One set of thresholds for every tile.
enum Livello: Equatable {
    case buono, medio, cattivo

    /// Load (CPU, RAM, 0...1): green under 60%, amber under 85%, red above.
    static func carico(_ v: Double) -> Livello { v < 0.6 ? .buono : v < 0.85 ? .medio : .cattivo }

    /// A battery: green above 40% or while charging, amber down to 21%, red at 20% and below.
    static func riserva(_ percento: Int, inCarica: Bool = false) -> Livello {
        inCarica || percento > 40 ? .buono : percento > 20 ? .medio : .cattivo
    }

    /// Free disk space in GB: green above 50, amber above 15, red below.
    static func spazio(_ gb: Double) -> Livello { gb > 50 ? .buono : gb > 15 ? .medio : .cattivo }
}
