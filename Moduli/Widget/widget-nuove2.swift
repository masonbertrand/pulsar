// 29/10: the second batch of tiles the user asked for: Bluetooth Battery, Snippets, Focus Stats, Stocks, Shortcuts,
// VPN, Countdown, Habits. Only Stocks uses the network (Yahoo Finance's public quote endpoint, no key, every 5 minutes
// while the tile is in sight). Pure helpers are in tessere-logica.swift.
import SwiftUI
import AppKit

private func esegui(_ path: String, _ args: [String]) -> String { SysToggles.run(path, args) }

private func copia(_ s: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s, forType: .string) }

/// A small one-line text prompt, like the weather city's.
private func chiedi(_ titolo: String, _ testo: String = "", valore: String = "", segnaposto: String = "") -> String? {
    NSApp.activate(ignoringOtherApps: true)
    let a = NSAlert(); a.messageText = titolo; a.informativeText = testo
    let f = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24)); f.stringValue = valore; f.placeholderString = segnaposto
    a.accessoryView = f; a.window.initialFirstResponder = f
    a.addButton(withTitle: "OK"); a.addButton(withTitle: T("Annulla", "Cancel"))
    return a.runModal() == .alertFirstButtonReturn ? f.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) : nil
}

// MARK: - Bluetooth Battery

final class BatterieModel: ObservableObject {
    static let shared = BatterieModel()
    @Published private(set) var voci: [BatterieBT.Voce] = []
    private var timer: Timer?
    private var spettatori = 0

    func guarda(_ on: Bool) {
        spettatori = max(0, spettatori + (on ? 1 : -1))
        if spettatori > 0, timer == nil {
            leggi()
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.leggi() }
        } else if spettatori == 0 { timer?.invalidate(); timer = nil }
    }

    private func leggi() {
        DispatchQueue.global(qos: .utility).async {
            let v = BatterieBT.leggi(esegui("/usr/sbin/system_profiler", ["SPBluetoothDataType"]))
            DispatchQueue.main.async { self.voci = v }
        }
    }
}

struct BluetoothBatteryWidget: IslandWidget {
    let id = "btbattery"
    var title: String { T("Batterie Bluetooth", "Bluetooth Battery") }
    let symbol = "airpods"
    func body(cells: Int) -> AnyView {
        AnyView(BTTile(m: .shared, cells: cells).tileTap(T("Impostazioni Bluetooth", "Bluetooth settings")) {
            TileOpen.url("x-apple.systempreferences:com.apple.BluetoothSettings")
        })
    }
}

private struct BTTile: View {
    @ObservedObject var m: BatterieModel
    let cells: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if m.voci.isEmpty {
                Image(systemName: "airpods").font(.system(size: 18)).foregroundStyle(Color.primary.opacity(0.45))
                if cells > 1 { Text(T("Nessun dispositivo con batteria", "No devices with a battery")).font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.55)) }
            }
            ForEach(m.voci.prefix(cells >= 2 ? 3 : 1), id: \.nome) { v in
                HStack(spacing: 6) {
                    Text(v.nome).font(.system(size: 11)).lineLimit(1)
                    Spacer(minLength: 4)
                    ForEach(v.livelli.sorted { $0.key < $1.key }, id: \.key) { e in
                        Text((e.key.isEmpty ? "" : String(e.key.prefix(1)) + " ") + "\(e.value)%")
                            .font(.system(size: 10.5).monospacedDigit()).foregroundStyle(Livello.riserva(e.value).colore)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: m.voci.isEmpty ? .center : .topLeading)
        .onAppear { m.guarda(true) }
        .onDisappear { m.guarda(false) }
    }
}

// MARK: - Snippets

struct SnippetsWidget: IslandWidget {
    let id = "snippets"
    var title: String { T("Frasi pronte", "Snippets") }
    let symbol = "text.badge.plus"
    func body(cells: Int) -> AnyView {
        AnyView(SnippetsTile(cells: cells).tileAction("plus", T("Salva un testo", "Save a snippet")) { SnippetsTile.aggiungi() })
    }
}

private struct SnippetsTile: View {
    let cells: Int
    @AppStorage(Chiave.frasiPronte.rawValue) private var dati = ""
    @State private var copiato: String?

    static func lista(_ s: String) -> [String] { (try? JSONDecoder().decode([String].self, from: Data(s.utf8))) ?? [] }
    static func salva(_ l: [String]) { UserDefaults.standard.set(String(decoding: (try? JSONEncoder().encode(l)) ?? Data(), as: UTF8.self), forKey: Chiave.frasiPronte.rawValue) }

    static func aggiungi() {
        let appunti = NSPasteboard.general.string(forType: .string) ?? ""
        guard let t = chiedi(T("Nuova frase pronta", "New snippet"), T("Un clic la copia negli appunti.", "One click copies it."), valore: appunti), !t.isEmpty else { return }
        var l = lista(UserDefaults.standard.string(forKey: Chiave.frasiPronte.rawValue) ?? "")
        l.removeAll { $0 == t }; l.insert(t, at: 0)
        salva(Array(l.prefix(20)))
    }

    var body: some View {
        let l = Self.lista(dati)
        VStack(alignment: .leading, spacing: 4) {
            if l.isEmpty {
                Text(T("Salva indirizzi, risposte, codici: un clic e sono copiati", "Save addresses, replies, codes: one click copies them"))
                    .font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.55)).padding(.trailing, 16)
            }
            ForEach(l.prefix(3), id: \.self) { t in
                Button { copia(t); copiato = t; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if copiato == t { copiato = nil } } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copiato == t ? "checkmark" : "doc.on.doc").font(.system(size: 9.5)).frame(width: 12)
                        Text(t).font(.system(size: 11)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 7).frame(height: 21)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.06)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu { Button(T("Elimina", "Delete")) { Self.salva(l.filter { $0 != t }) } }
                .hint(T("Copia (clic destro per eliminare)", "Copy (right-click to delete)"))
            }
        }
        .padding(.trailing, l.isEmpty ? 0 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Focus Stats (the minutes the dial's timer ran to the end)

final class FocusStats: ObservableObject {
    static let shared = FocusStats()
    @Published private(set) var minuti: [String: Int] = (Impostazioni.dictionary(.focusMinuti) as? [String: Int]) ?? [:]
    @Published private(set) var sessioni: [String: Int] = (Impostazioni.dictionary(.focusSessioni) as? [String: Int]) ?? [:]

    /// Called by the dial when a timer finishes.
    func registra(minuti m: Int) {
        let g = Abitudini.giorno(Date())
        minuti[g, default: 0] += m; sessioni[g, default: 0] += 1
        Impostazioni.set(minuti, .focusMinuti); Impostazioni.set(sessioni, .focusSessioni)
    }
}

struct FocusStatsWidget: IslandWidget {
    let dial: DialStore?
    let id = "focusstats"
    var title: String { T("Statistiche focus", "Focus Stats") }
    let symbol = "chart.bar.fill"
    func body(cells: Int) -> AnyView { AnyView(FocusStatsTile(s: .shared, dial: dial, cells: cells)) }
}

private struct FocusStatsTile: View {
    @ObservedObject var s: FocusStats
    let dial: DialStore?
    let cells: Int
    var body: some View {
        let oggi = Abitudini.giorno(Date())
        let sett = StatisticheFocus.settimana(s.minuti, oggi: Date())
        let massimo = max(25, sett.max() ?? 0)
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(s.minuti[oggi] ?? 0) min").font(.system(size: 20, weight: .light).monospacedDigit())
                Text(T("\(s.sessioni[oggi] ?? 0) sessioni oggi", "\(s.sessioni[oggi] ?? 0) sessions today")).font(.system(size: 10.5)).foregroundStyle(Color.primary.opacity(0.55))
                Spacer(minLength: 2)
                if let dial { AvviaFocus(dial: dial) }
            }
            if cells >= 2 {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(sett.enumerated()), id: \.offset) { i, m in
                        Capsule().fill(i == sett.count - 1 ? Volta.a2 : Color.primary.opacity(0.25))
                            .frame(width: 7, height: max(3, CGFloat(m) / CGFloat(massimo) * 56))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .hint(T("Minuti di focus, ultimi 7 giorni", "Focus minutes, last 7 days"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Starts or stops the dial's timer, and follows it.
private struct AvviaFocus: View {
    @ObservedObject var dial: DialStore
    var body: some View {
        Button {
            if dial.timerEnd == nil { dial.timerEnd = Date().addingTimeInterval(Double(dial.timerMinutes * 60)); dial.now = Date() } else { dial.timerEnd = nil }
        } label: {
            Label(dial.timerEnd == nil ? T("Avvia \(dial.timerMinutes) min", "Start \(dial.timerMinutes) min") : T("Ferma", "Stop"),
                  systemImage: dial.timerEnd == nil ? "play.fill" : "stop.fill")
                .font(.system(size: 10.5, weight: .medium)).padding(.horizontal, 8).frame(height: 22)
                .background(Capsule().fill(Color.primary.opacity(0.09))).contentShape(Capsule())
        }
        .buttonStyle(.plain).hint(T("Il timer della ghiera", "The dial's timer"))
    }
}

// MARK: - Stocks

final class QuoteModel: ObservableObject {
    static let shared = QuoteModel()
    @Published private(set) var prezzi: [Quote.Prezzo] = []
    private var timer: Timer?
    private var spettatori = 0

    var simboli: [String] {
        (UserDefaults.standard.string(forKey: Chiave.quoteSimboli.rawValue) ?? "AAPL,^GSPC,BTC-USD")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).uppercased() }.filter { !$0.isEmpty }
    }

    func guarda(_ on: Bool) {
        spettatori = max(0, spettatori + (on ? 1 : -1))
        if spettatori > 0, timer == nil {
            aggiorna()
            timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.aggiorna() }
        } else if spettatori == 0 { timer?.invalidate(); timer = nil }
    }

    func aggiorna() {
        let lista = simboli
        var raccolti: [String: Quote.Prezzo] = [:]
        let gruppo = DispatchGroup()
        for s in lista {
            guard let q = s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let u = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(q)?range=1d&interval=1d") else { continue }
            var r = URLRequest(url: u, timeoutInterval: 8)
            r.setValue("Mozilla/5.0 Pulsar", forHTTPHeaderField: "User-Agent")
            gruppo.enter()
            URLSession.shared.dataTask(with: r) { d, _, _ in
                if let d, let p = Quote.leggi(d) { DispatchQueue.main.async { raccolti[s] = p } }
                gruppo.leave()
            }.resume()
        }
        gruppo.notify(queue: .main) { [weak self] in
            DispatchQueue.main.async { self?.prezzi = lista.compactMap { raccolti[$0] } }
        }
    }

    func modifica() {
        guard let t = chiedi(T("Titoli e cripto", "Stocks and crypto"), T("Simboli di Yahoo Finance separati da virgole.", "Yahoo Finance symbols, comma separated (e.g. AAPL, ^GSPC, BTC-USD)."),
                             valore: simboli.joined(separator: ", ")) else { return }
        UserDefaults.standard.set(t, forKey: Chiave.quoteSimboli.rawValue)
        aggiorna()
    }
}

struct StocksWidget: IslandWidget {
    let id = "stocks"
    var title: String { T("Borsa e cripto", "Stocks & Crypto") }
    let symbol = "chart.line.uptrend.xyaxis"
    func body(cells: Int) -> AnyView {
        AnyView(StocksTile(m: .shared, cells: cells).tileAction("pencil", T("Scegli i titoli", "Choose symbols")) { QuoteModel.shared.modifica() })
    }
}

private struct StocksTile: View {
    @ObservedObject var m: QuoteModel
    let cells: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if m.prezzi.isEmpty { Text(T("Carico…", "Loading…")).font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.5)) }
            ForEach(m.prezzi.prefix(cells >= 2 ? 3 : 2), id: \.simbolo) { p in
                Button {
                    if let u = URL(string: "https://finance.yahoo.com/quote/\(p.simbolo.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? p.simbolo)") { NSWorkspace.shared.open(u) }
                } label: {
                    HStack(spacing: 6) {
                        Text(p.simbolo).font(.system(size: 11, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 4)
                        if cells >= 2 { Text(Quote.testo(p.prezzo)).font(.system(size: 11).monospacedDigit()).foregroundStyle(Color.primary.opacity(0.75)) }
                        Text(String(format: "%+.2f%%", p.variazione)).font(.system(size: 10.5, weight: .medium).monospacedDigit())
                            .foregroundStyle(p.variazione >= 0 ? Night.green : Night.red)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).hint(T("Apri su Yahoo Finance", "Open on Yahoo Finance"))
            }
        }
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { m.guarda(true) }
        .onDisappear { m.guarda(false) }
    }
}

// MARK: - Shortcuts

struct ShortcutsWidget: IslandWidget {
    let id = "shortcuts"
    var title: String { T("Comandi rapidi", "Shortcuts") }
    let symbol = "square.2.layers.3d"
    func body(cells: Int) -> AnyView {
        AnyView(ShortcutsTile(cells: cells).tileAction("plus", T("Aggiungi un comando rapido", "Add a shortcut")) { ShortcutsTile.aggiungi() })
    }
}

private struct ShortcutsTile: View {
    let cells: Int
    @AppStorage(Chiave.comandiFissati.rawValue) private var fissati = ""
    @State private var fatto: String?

    static func aggiungi() {
        DispatchQueue.global(qos: .userInitiated).async {
            let tutti = esegui("/usr/bin/shortcuts", ["list"]).split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                let a = NSAlert(); a.messageText = T("Fissa un comando rapido", "Pin a shortcut")
                let p = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 26)); p.addItems(withTitles: tutti)
                a.accessoryView = p
                if tutti.isEmpty { a.informativeText = T("Non hai ancora comandi rapidi: creane uno nell'app Comandi Rapidi.", "You have no shortcuts yet: make one in the Shortcuts app.") }
                a.addButton(withTitle: T("Fissa", "Pin")); a.addButton(withTitle: T("Annulla", "Cancel"))
                guard a.runModal() == .alertFirstButtonReturn, let n = p.titleOfSelectedItem else { return }
                var l = (UserDefaults.standard.string(forKey: Chiave.comandiFissati.rawValue) ?? "").split(separator: "\n").map(String.init)
                if !l.contains(n) { l.append(n) }
                UserDefaults.standard.set(l.joined(separator: "\n"), forKey: Chiave.comandiFissati.rawValue)
            }
        }
    }

    var body: some View {
        let l = fissati.split(separator: "\n").map(String.init)
        Group {
            if l.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "square.2.layers.3d").font(.system(size: 18)).foregroundStyle(Color.primary.opacity(0.45))
                    if cells > 1 { Text(T("Fissa i tuoi comandi rapidi con +", "Pin your shortcuts with +")).font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.55)) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: max(1, cells - 1)), spacing: 5) {
                    ForEach(l.prefix(max(2, (cells - 1) * 3)), id: \.self) { n in
                        Button { lancia(n) } label: {
                            HStack(spacing: 5) {
                                Image(systemName: fatto == n ? "checkmark" : "play.fill").font(.system(size: 8.5))
                                Text(n).font(.system(size: 10.5)).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 7).frame(height: 22)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.07))).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu { Button(T("Togli", "Unpin")) { fissati = l.filter { $0 != n }.joined(separator: "\n") } }
                        .hint(T("Esegui (clic destro per togliere)", "Run (right-click to unpin)"))
                    }
                }
                .padding(.trailing, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func lancia(_ n: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = SysToggles.run("/usr/bin/shortcuts", ["run", n])
            DispatchQueue.main.async { fatto = n; DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if fatto == n { fatto = nil } } }
        }
    }
}

// MARK: - VPN

final class VPNModel: ObservableObject {
    static let shared = VPNModel()
    @Published private(set) var voci: [VPN.Voce] = []
    private var timer: Timer?
    private var spettatori = 0

    func guarda(_ on: Bool) {
        spettatori = max(0, spettatori + (on ? 1 : -1))
        if spettatori > 0, timer == nil {
            leggi()
            timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.leggi() }
        } else if spettatori == 0 { timer?.invalidate(); timer = nil }
    }

    func leggi() {
        DispatchQueue.global(qos: .utility).async {
            let v = VPN.leggi(esegui("/usr/sbin/scutil", ["--nc", "list"]))
            DispatchQueue.main.async { self.voci = v }
        }
    }

    func cambia(_ v: VPN.Voce) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = esegui("/usr/sbin/scutil", ["--nc", v.connessa ? "stop" : "start", v.nome])
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.leggi() }
        }
    }
}

struct VPNWidget: IslandWidget {
    let id = "vpn"
    var title: String { "VPN" }
    let symbol = "lock.shield"
    func body(cells: Int) -> AnyView { AnyView(VPNTile(m: .shared, cells: cells)) }
}

private struct VPNTile: View {
    @ObservedObject var m: VPNModel
    let cells: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if m.voci.isEmpty {
                Button { TileOpen.url("x-apple.systempreferences:com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension") } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "lock.shield").font(.system(size: 18)).foregroundStyle(Color.primary.opacity(0.45))
                        if cells > 1 { Text(T("Nessuna VPN configurata", "No VPN set up")).font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.55)) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.plain).hint(T("Impostazioni VPN", "VPN settings"))
            }
            ForEach(m.voci.prefix(cells >= 2 ? 3 : 1), id: \.nome) { v in
                Button { m.cambia(v) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: v.connessa ? "lock.fill" : "lock.open").font(.system(size: 11)).foregroundStyle(v.connessa ? Night.green : Color.primary.opacity(0.55))
                        Text(v.nome).font(.system(size: 11.5)).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(v.connessa ? T("Connessa", "On") : T("Spenta", "Off")).font(.system(size: 10.5)).foregroundStyle(Color.primary.opacity(0.55))
                    }
                    .padding(.horizontal, 8).frame(height: 24)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(v.connessa ? Night.green.opacity(0.15) : Color.primary.opacity(0.06)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).hint(v.connessa ? T("Disconnetti", "Disconnect") : T("Connetti", "Connect"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { m.guarda(true) }
        .onDisappear { m.guarda(false) }
    }
}

// MARK: - Countdown

struct CountdownWidget: IslandWidget {
    let id = "countdown"
    var title: String { T("Conto alla rovescia", "Countdown") }
    let symbol = "hourglass"
    func body(cells: Int) -> AnyView {
        AnyView(CountdownTile(cells: cells).tileTap(T("Scegli data e nome", "Choose the date and name")) { CountdownTile.modifica() }
            .tileAction("pencil", T("Modifica", "Edit")) { CountdownTile.modifica() })
    }
}

private struct CountdownTile: View {
    let cells: Int
    @AppStorage(Chiave.contoNome.rawValue) private var nome = ""
    @AppStorage(Chiave.contoData.rawValue) private var data: Double = 0

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            if data == 0 {
                VStack(spacing: 4) {
                    Image(systemName: "hourglass").font(.system(size: 18)).foregroundStyle(Color.primary.opacity(0.45))
                    if cells > 1 { Text(T("Conta i giorni a una data", "Count the days to a date")).font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.55)) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let d = Date(timeIntervalSince1970: data)
                let n = ContoAllaRovescia.giorni(a: d, da: ctx.date)
                VStack(alignment: .leading, spacing: 1) {
                    Text(nome.isEmpty ? T("Mancano", "Days left") : nome).font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.6)).lineLimit(1)
                    Text(n == 0 ? T("Oggi", "Today") : "\(abs(n))").font(.system(size: 28, weight: .light).monospacedDigit())
                    Text(n == 0 ? d.formatted(date: .abbreviated, time: .omitted) : n > 0 ? T("giorni", "days to go") : T("giorni fa", "days ago"))
                        .font(.system(size: 10.5)).foregroundStyle(Color.primary.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    static func modifica() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert(); a.messageText = T("Conto alla rovescia", "Countdown")
        let campo = NSTextField(frame: NSRect(x: 0, y: 34, width: 280, height: 24)); campo.placeholderString = T("Cosa (es. Vacanze)", "What (e.g. Vacation)")
        campo.stringValue = UserDefaults.standard.string(forKey: Chiave.contoNome.rawValue) ?? ""
        let picker = NSDatePicker(frame: NSRect(x: 0, y: 0, width: 280, height: 26))
        picker.datePickerElements = .yearMonthDay; picker.datePickerStyle = .textFieldAndStepper
        let salvata = UserDefaults.standard.double(forKey: Chiave.contoData.rawValue)
        picker.dateValue = salvata > 0 ? Date(timeIntervalSince1970: salvata) : Date().addingTimeInterval(7 * 86400)
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 60)); v.addSubview(campo); v.addSubview(picker)
        a.accessoryView = v; a.window.initialFirstResponder = campo
        a.addButton(withTitle: "OK"); a.addButton(withTitle: T("Annulla", "Cancel"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        UserDefaults.standard.set(campo.stringValue.trimmingCharacters(in: .whitespaces), forKey: Chiave.contoNome.rawValue)
        UserDefaults.standard.set(picker.dateValue.timeIntervalSince1970, forKey: Chiave.contoData.rawValue)
    }
}

// MARK: - Habits

final class AbitudiniModel: ObservableObject {
    static let shared = AbitudiniModel()
    @Published var nomi: [String] = (UserDefaults.standard.string(forKey: Chiave.abitudiniNomi.rawValue) ?? "Exercise,Read,Water")
        .split(separator: ",").map(String.init) {
        didSet { UserDefaults.standard.set(nomi.joined(separator: ","), forKey: Chiave.abitudiniNomi.rawValue) }
    }
    @Published private(set) var fatti: [String: [String]] = (Impostazioni.dictionary(.abitudiniFatte) as? [String: [String]]) ?? [:]

    func fatto(_ n: String, _ g: String) -> Bool { fatti[n]?.contains(g) == true }

    func cambia(_ n: String) {
        let g = Abitudini.giorno(Date())
        var l = fatti[n] ?? []
        if l.contains(g) { l.removeAll { $0 == g } } else { l.append(g) }
        fatti[n] = Array(l.suffix(400))
        Impostazioni.set(fatti, .abitudiniFatte)
    }

    func serie(_ n: String) -> Int { Abitudini.serie(Set(fatti[n] ?? []), oggi: Date()) }

    func modifica() {
        guard let t = chiedi(T("Abitudini", "Habits"), T("Fino a quattro, separate da virgole.", "Up to four, separated by commas."), valore: nomi.joined(separator: ", ")) else { return }
        let l = t.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !l.isEmpty { nomi = Array(l.prefix(4)) }
    }
}

struct HabitsWidget: IslandWidget {
    let id = "habits"
    var title: String { T("Abitudini", "Habits") }
    let symbol = "checkmark.circle"
    func body(cells: Int) -> AnyView {
        AnyView(HabitsTile(m: .shared, cells: cells).tileAction("pencil", T("Modifica le abitudini", "Edit habits")) { AbitudiniModel.shared.modifica() })
    }
}

private struct HabitsTile: View {
    @ObservedObject var m: AbitudiniModel
    let cells: Int
    var body: some View {
        let oggi = Abitudini.giorno(Date())
        VStack(alignment: .leading, spacing: 4) {
            ForEach(m.nomi.prefix(cells >= 2 ? 3 : 2), id: \.self) { n in
                let ok = m.fatto(n, oggi)
                Button { m.cambia(n) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: ok ? "checkmark.circle.fill" : "circle").font(.system(size: 12))
                            .foregroundStyle(ok ? Night.green : Color.primary.opacity(0.45))
                        Text(n).font(.system(size: 11.5)).lineLimit(1)
                        Spacer(minLength: 0)
                        let s = m.serie(n)
                        if s > 0 && cells >= 2 {
                            Text(T("\(s) gg", "\(s)d")).font(.system(size: 10.5).monospacedDigit()).foregroundStyle(Color.primary.opacity(0.5))
                        }
                    }
                    .frame(height: 20).contentShape(Rectangle())
                }
                .buttonStyle(.plain).hint(ok ? T("Fatto oggi: clic per togliere", "Done today: click to undo") : T("Segna come fatto oggi", "Mark done today"))
            }
        }
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
