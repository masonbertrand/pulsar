// 29/10: new tiles the user asked for ("come up with ideas for more tiles that could be useful"):
// World Clock, Keep Awake, Screenshot, Color Picker, Scratchpad, Network. No new network access; Screenshot uses the
// Screen Recording permission Pulsar already asks for its window thumbnails. Pure helpers are in strumenti-schede-logica.swift.
import SwiftUI
import AppKit

// MARK: - Keep Awake (shared with the menu bar's Keep Awake)

final class TieniSveglio: ObservableObject {
    static let shared = TieniSveglio()
    @Published private(set) var attivo = false
    @Published private(set) var fino: Date?
    private var p: Process?

    func cambia() { attivo ? ferma() : avvia() }

    /// Keeps the display and the Mac awake; for `secondi`, or until turned off.
    func avvia(secondi: Int? = nil) {
        ferma()
        let q = Process()
        q.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        q.arguments = ["-di"] + (secondi.map { ["-t", "\($0)"] } ?? [])
        q.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async { if self?.p === proc { self?.p = nil; self?.attivo = false; self?.fino = nil } }
        }
        guard (try? q.run()) != nil else { return }
        p = q; attivo = true
        fino = secondi.map { Date().addingTimeInterval(Double($0)) }
    }

    func ferma() { let q = p; p = nil; q?.terminate(); attivo = false; fino = nil }
}

struct KeepAwakeWidget: IslandWidget {
    let id = "keepawake"
    var title: String { T("Sempre acceso", "Keep Awake") }
    let symbol = "cup.and.saucer.fill"
    func body(cells: Int) -> AnyView { AnyView(KeepAwakeTile(s: .shared, cells: cells)) }
}

private struct KeepAwakeTile: View {
    @ObservedObject var s: TieniSveglio
    let cells: Int
    var body: some View {
        HStack(spacing: 10) {
            Button { s.cambia() } label: {
                Image(systemName: s.attivo ? "cup.and.saucer.fill" : "cup.and.saucer").font(.system(size: 20))
                    .foregroundStyle(s.attivo ? Night.amber : Color.primary.opacity(0.6))
                    .frame(width: 44, height: 44).background(Circle().fill(Color.primary.opacity(s.attivo ? 0.12 : 0.06))).contentShape(Circle())
            }
            .buttonStyle(.plain).hint(s.attivo ? T("Lascia dormire il Mac", "Let the Mac sleep") : T("Tieni sveglio il Mac", "Keep the Mac awake"))
            if cells >= 2 {
                VStack(alignment: .leading, spacing: 4) {
                    TimelineView(.everyMinute) { ctx in
                        Text(s.attivo ? (s.fino.map { T("Sveglio fino alle \($0.formatted(date: .omitted, time: .shortened))", "Awake until \($0.formatted(date: .omitted, time: .shortened))") }
                                         ?? T("Sveglio finché lo spegni", "Awake until you turn it off"))
                                      : T("Dorme normalmente", "Sleeps normally"))
                            .font(.system(size: 11)).foregroundStyle(Color.primary.opacity(0.65)).lineLimit(2)
                            .id(ctx.date)
                    }
                    HStack(spacing: 5) {
                        durata("30m", 1800); durata("1h", 3600); durata("2h", 7200)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func durata(_ nome: String, _ sec: Int) -> some View {
        Button { s.avvia(secondi: sec) } label: {
            Text(nome).font(.system(size: 10.5, weight: .medium)).padding(.horizontal, 7).frame(height: 20)
                .background(Capsule().fill(Color.primary.opacity(0.08))).contentShape(Capsule())
        }
        .buttonStyle(.plain).hint(T("Sveglio per \(nome)", "Awake for \(nome)"))
    }
}

// MARK: - World Clock

struct WorldClockWidget: IslandWidget {
    let id = "worldclock"
    var title: String { T("Orologio mondiale", "World Clock") }
    let symbol = "globe"
    func body(cells: Int) -> AnyView {
        AnyView(WorldClockTile(cells: cells).tileTap(T("Apri Orologio", "Open Clock")) { TileOpen.app("Clock") }
            .tileAction("pencil", T("Scegli le città", "Choose cities")) { WorldClockTile.scegli() })
    }
}

private struct WorldClockTile: View {
    let cells: Int
    @AppStorage(Chiave.orologiFusi.rawValue) private var fusi = "America/New_York,Europe/London,Asia/Tokyo"

    var body: some View {
        let ids = fusi.split(separator: ",").map(String.init).filter { TimeZone(identifier: $0) != nil }
        TimelineView(.everyMinute) { ctx in
            HStack(spacing: 10) {
                ForEach(ids.prefix(max(1, min(cells, 3))), id: \.self) { id in
                    let tz = TimeZone(identifier: id)!
                    VStack(alignment: .leading, spacing: 1) {
                        Text(FusoOrario.nome(id)).font(.system(size: 10.5)).foregroundStyle(Color.primary.opacity(0.6)).lineLimit(1)
                        Text(ctx.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: tz)))
                            .font(.system(size: 18, weight: .light).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                        Text(Self.differenza(tz, ctx.date)).font(.system(size: 9.5)).foregroundStyle(Color.primary.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// "+6h", "−3h", "same time".
    static func differenza(_ tz: TimeZone, _ d: Date) -> String {
        let h = Double(tz.secondsFromGMT(for: d) - TimeZone.current.secondsFromGMT(for: d)) / 3600
        if h == 0 { return T("stessa ora", "same time") }
        let n = h == h.rounded() ? String(Int(h)) : String(format: "%.1f", h)
        return (h > 0 ? "+" : "") + n + "h"
    }

    static func scegli() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = T("Città dell'orologio", "World Clock cities")
        a.informativeText = T("Fino a tre, separate da virgole (es. New York, London, Tokyo).", "Up to three, separated by commas (e.g. New York, London, Tokyo).")
        let f = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        f.stringValue = (UserDefaults.standard.string(forKey: Chiave.orologiFusi.rawValue) ?? "").split(separator: ",").map { FusoOrario.nome(String($0)) }.joined(separator: ", ")
        a.accessoryView = f
        a.addButton(withTitle: "OK"); a.addButton(withTitle: T("Annulla", "Cancel"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let ids = f.stringValue.split(separator: ",").compactMap { FusoOrario.cerca(String($0)) }
        if !ids.isEmpty { UserDefaults.standard.set(ids.prefix(3).joined(separator: ","), forKey: Chiave.orologiFusi.rawValue) }
    }
}

// MARK: - Screenshot

struct ScreenshotWidget: IslandWidget {
    let id = "screenshot"
    var title: String { "Screenshot" }
    let symbol = "camera.viewfinder"
    func body(cells: Int) -> AnyView { AnyView(ScreenshotTile(cells: cells)) }
}

private struct ScreenshotTile: View {
    let cells: Int
    var body: some View {
        HStack(spacing: 6) {
            scatto("rectangle.dashed", T("Area", "Area"), T("Un'area, negli appunti", "An area, to the clipboard"), ["-ic"], attesa: 0.7)
            scatto("macwindow", T("Finestra", "Window"), T("Una finestra, negli appunti", "A window, to the clipboard"), ["-iWc"], attesa: 0.7)
            if cells >= 2 {
                scatto("display", T("Schermo", "Screen"), T("Tutto lo schermo, sulla Scrivania", "The whole screen, to the Desktop"), [Self.file()], attesa: 1.2)
            }
            if cells >= 3 {
                Button { TileOpen.app("Utilities/Screenshot") } label: { voce("record.circle", T("Registra", "Record")) }
                    .buttonStyle(.plain).hint(T("Registra lo schermo (app Screenshot)", "Record the screen (Screenshot app)"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scatto(_ s: String, _ nome: String, _ aiuto: String, _ arg: [String], attesa: Double) -> some View {
        Button {
            // a moment for the island to get out of the way before the capture starts
            DispatchQueue.main.asyncAfter(deadline: .now() + attesa) {
                let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture"); p.arguments = arg
                try? p.run()
            }
        } label: { voce(s, nome) }
        .buttonStyle(.plain).hint(aiuto)
    }

    private func voce(_ s: String, _ nome: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: s).font(.system(size: 16))
            if cells >= 2 { Text(nome).font(.system(size: 10)) }
        }
        .foregroundStyle(Color.primary.opacity(0.8))
        .frame(maxWidth: .infinity).frame(height: cells >= 2 ? 56 : 40)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.07)))
        .contentShape(Rectangle())
    }

    static func file() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0].appendingPathComponent("Screenshot \(f.string(from: Date())).png").path
    }
}

// MARK: - Color Picker

struct ColorPickerWidget: IslandWidget {
    let id = "colorpicker"
    var title: String { T("Contagocce", "Color Picker") }
    let symbol = "eyedropper"
    func body(cells: Int) -> AnyView { AnyView(ColorPickerTile(cells: cells)) }
}

private struct ColorPickerTile: View {
    let cells: Int
    @AppStorage(Chiave.coloriRecenti.rawValue) private var recenti = ""
    @State private var copiato: String?

    var body: some View {
        let lista = recenti.split(separator: ",").map(String.init)
        HStack(spacing: 10) {
            Button { prendi() } label: {
                Image(systemName: "eyedropper").font(.system(size: 18)).foregroundStyle(Color.primary.opacity(0.8))
                    .frame(width: 44, height: 44).background(Circle().fill(Color.primary.opacity(0.08))).contentShape(Circle())
            }
            .buttonStyle(.plain).hint(T("Prendi un colore dallo schermo", "Pick a colour from the screen"))
            if cells >= 2 {
                VStack(alignment: .leading, spacing: 5) {
                    Text(copiato.map { T("Copiato \($0)", "Copied \($0)") } ?? (lista.first ?? T("Nessun colore", "No colours yet")))
                        .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Color.primary.opacity(0.7)).lineLimit(1)
                    HStack(spacing: 5) {
                        ForEach(lista.prefix(cells >= 3 ? 7 : 4), id: \.self) { h in
                            Button { copia(h) } label: {
                                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Self.colore(h)).frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain).hint(T("Copia \(h)", "Copy \(h)"))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func prendi() {
        NSColorSampler().show { c in
            guard let c = c?.usingColorSpace(.sRGB) else { return }
            let h = Colore.hex(Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
            var l = recenti.split(separator: ",").map(String.init).filter { $0 != h }
            l.insert(h, at: 0)
            recenti = l.prefix(12).joined(separator: ",")
            copia(h)
        }
    }

    private func copia(_ h: String) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(h, forType: .string)
        copiato = h
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if copiato == h { copiato = nil } }
    }

    static func colore(_ h: String) -> Color {
        let v = Int(h.dropFirst(), radix: 16) ?? 0
        return Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }
}

// MARK: - Scratchpad

struct ScratchpadWidget: IslandWidget {
    let id = "scratchpad"
    var title: String { T("Appunti veloci", "Scratchpad") }
    let symbol = "note.text"
    func body(cells: Int) -> AnyView {
        AnyView(ScratchpadTile(cells: cells).tileTap(T("Scrivi", "Write")) { ScratchpadTile.modifica() }
            .tileAction("doc.on.doc", T("Copia il testo", "Copy the text")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(UserDefaults.standard.string(forKey: Chiave.notaRapida.rawValue) ?? "", forType: .string)
            })
    }
}

private struct ScratchpadTile: View {
    let cells: Int
    @AppStorage(Chiave.notaRapida.rawValue) private var nota = ""
    var body: some View {
        Text(nota.isEmpty ? T("Clicca per scrivere qualcosa da tenere a portata di mano", "Click to jot something down") : nota)
            .font(.system(size: 11.5)).foregroundStyle(Color.primary.opacity(nota.isEmpty ? 0.5 : 0.85))
            .lineLimit(4).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(.trailing, 14)
    }

    static func modifica() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = T("Appunti veloci", "Scratchpad")
        let sv = NSScrollView(frame: NSRect(x: 0, y: 0, width: 340, height: 160)); sv.hasVerticalScroller = true; sv.borderType = .bezelBorder
        let tv = NSTextView(frame: sv.bounds); tv.isRichText = false; tv.font = .systemFont(ofSize: 13); tv.autoresizingMask = [.width, .height]
        tv.string = UserDefaults.standard.string(forKey: Chiave.notaRapida.rawValue) ?? ""
        sv.documentView = tv
        a.accessoryView = sv
        a.window.initialFirstResponder = tv
        a.addButton(withTitle: T("Salva", "Save")); a.addButton(withTitle: T("Annulla", "Cancel"))
        if a.runModal() == .alertFirstButtonReturn { UserDefaults.standard.set(tv.string, forKey: Chiave.notaRapida.rawValue) }
    }
}

// MARK: - Network

struct NetworkWidget: IslandWidget {
    let id = "network"
    var title: String { T("Rete", "Network") }
    let symbol = "network"
    func body(cells: Int) -> AnyView {
        AnyView(NetworkTile(perf: .shared, cells: cells).tileTap(T("Impostazioni Rete", "Network settings")) {
            TileOpen.url("x-apple.systempreferences:com.apple.Network-Settings.extension")
        })
    }
}

private struct NetworkTile: View {
    @ObservedObject var perf: PerfMonitor
    let cells: Int
    @State private var ip = NetworkTile.indirizzo()
    @State private var copiato = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Label(PerfMonitor.speed(perf.down), systemImage: "arrow.down").font(.system(size: 11).monospacedDigit()).foregroundStyle(ColoriRete.giu)
                if cells >= 2 { Label(PerfMonitor.speed(perf.up), systemImage: "arrow.up").font(.system(size: 11).monospacedDigit()).foregroundStyle(ColoriRete.su) }
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Text(ip ?? T("Non connesso", "Offline")).font(.system(size: cells >= 2 ? 15 : 12, weight: .light).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                if let ip, cells >= 2 {
                    Button {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(ip, forType: .string)
                        copiato = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiato = false }
                    } label: {
                        Image(systemName: copiato ? "checkmark" : "doc.on.doc").font(.system(size: 10)).foregroundStyle(Color.primary.opacity(0.6))
                            .frame(width: 20, height: 20).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).hint(T("Copia l'indirizzo IP", "Copy the IP address"))
                }
            }
            // 29/10: green when connected, red when offline
            HStack(spacing: 5) {
                Circle().fill((ip == nil ? Livello.cattivo : Livello.buono).colore).frame(width: 6, height: 6)
                Text(ip == nil ? T("Offline", "Offline") : T("Connesso · indirizzo locale", "Connected · local address"))
                    .font(.system(size: 9.5)).foregroundStyle(Color.primary.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { perf.watch(true); ip = Self.indirizzo() }
        .onDisappear { perf.watch(false) }
    }

    /// The Mac's IPv4 address on Wi-Fi or Ethernet (en0, en1…).
    static func indirizzo() -> String? {
        var lista: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&lista) == 0, let primo = lista else { return nil }
        defer { freeifaddrs(lista) }
        for p in sequence(first: primo, next: { $0.pointee.ifa_next }) {
            let i = p.pointee
            guard let a = i.ifa_addr, a.pointee.sa_family == UInt8(AF_INET), String(cString: i.ifa_name).hasPrefix("en") else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(a, socklen_t(a.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                return String(cString: host)
            }
        }
        return nil
    }
}
