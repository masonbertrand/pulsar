// 28/10: the island's new tabs, as the user asked: Communications (instead of Work), Files, Music, Meetings, Notion.
// No new network access and no new permissions beyond what each job needs: Communications reads the Dock's red badges
// and the banners Pulsar already captures (Accessibility, already granted); Files lists the Downloads folder (macOS asks
// once); Meetings uses the calendars already allowed; Notion is shortcuts and pinned pages that open in the Notion app.
// The pure parts are in schede-logica.swift.
import SwiftUI
import AppKit

// MARK: - Shared pieces

/// A row button with an icon and a name, for the tabs' right-hand columns.
private struct TastoScheda: View {
    let simbolo: String
    let titolo: String
    var principale = false
    let azione: () -> Void
    var body: some View {
        Button(action: azione) {
            HStack(spacing: 8) {
                Image(systemName: simbolo).font(.system(size: 11.5, weight: .medium)).frame(width: 15)
                Text(titolo).font(.system(size: 12)).lineLimit(1).minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .foregroundStyle(principale ? Volta.primT : Volta.t1)
            .padding(.horizontal, 9).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(principale ? Volta.prim : Volta.card2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A small round icon button for list rows.
private struct TastoTondo: View {
    let simbolo: String
    let nome: String
    let azione: () -> Void
    var body: some View {
        Button(action: azione) {
            Image(systemName: simbolo).font(.system(size: 10.5, weight: .medium)).foregroundStyle(Volta.t2)
                .frame(width: 24, height: 24).background(Circle().fill(Volta.card2)).contentShape(Circle())
        }
        .buttonStyle(.plain).hint(nome)
    }
}

private struct Titoletto: View {
    let testo: String
    var destra: String? = nil
    var body: some View {
        HStack {
            Text(testo).font(.system(size: 12, weight: .medium)).foregroundStyle(Volta.t2)
            Spacer()
            if let destra { Text(destra).font(.system(size: 11.5)).foregroundStyle(Volta.t3) }
        }
    }
}

enum ApriApp {
    /// Opens an app by bundle id, or by its name in /Applications, or the web page if it isn't installed.
    static func apri(bundle: String? = nil, nome: String, web: String? = nil) {
        let ws = NSWorkspace.shared
        if let b = bundle, let u = ws.urlForApplication(withBundleIdentifier: b) {
            ws.openApplication(at: u, configuration: NSWorkspace.OpenConfiguration()); return
        }
        for cartella in ["/Applications", NSHomeDirectory() + "/Applications"] {
            let p = "\(cartella)/\(nome).app"
            if FileManager.default.fileExists(atPath: p) { ws.openApplication(at: URL(fileURLWithPath: p), configuration: NSWorkspace.OpenConfiguration()); return }
        }
        if let w = web, let u = URL(string: w) { ws.open(u) }
    }
}

// MARK: - Communications

/// The Dock's apps and their red badges, read with Accessibility (no new permission).
final class DockBadges: ObservableObject {
    static let shared = DockBadges()
    struct App: Identifiable, Equatable { var id: String { nome }; let nome: String; let url: URL?; let badge: String? }
    @Published private(set) var app: [App] = []
    private var timer: Timer?

    func guarda(_ on: Bool) {
        timer?.invalidate(); timer = nil
        guard on else { return }
        aggiorna()
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in self?.aggiorna() }
    }

    func aggiorna() {
        guard AXIsProcessTrusted(), let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return }
        let radice = AXUIElementCreateApplication(dock.processIdentifier)
        var out: [App] = []
        for lista in Self.figli(radice) where Self.attr(lista, kAXRoleAttribute) as? String == "AXList" {
            for el in Self.figli(lista) {
                guard let nome = Self.attr(el, kAXTitleAttribute) as? String,
                      let url = (Self.attr(el, "AXURL") as? NSURL).map({ $0 as URL }), url.pathExtension == "app" else { continue }
                out.append(App(nome: nome, url: url, badge: Self.attr(el, "AXStatusLabel") as? String))
            }
        }
        if out != app { app = out }
    }

    var totale: Int { app.compactMap { CommsLogic.conteggio($0.badge) }.reduce(0, +) }

    private static func attr(_ el: AXUIElement, _ nome: String) -> AnyObject? {
        var v: AnyObject?
        return AXUIElementCopyAttributeValue(el, nome as CFString, &v) == .success ? v : nil
    }
    private static func figli(_ el: AXUIElement) -> [AXUIElement] { attr(el, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
}

/// Two columns of compact buttons, for the tabs' right-hand side.
private struct GrigliaTasti<C: View>: View {
    @ViewBuilder let c: () -> C
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) { c() }
    }
}

struct CommsTab: View {
    @ObservedObject private var dock = DockBadges.shared
    @ObservedObject private var log = NotificationLog.shared

    var body: some View {
        HStack(spacing: 8) {
            VCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    let tot = dock.totale
                    Titoletto(testo: T("Da leggere", "Unread"), destra: tot == 0 ? T("tutto letto", "all caught up") : "\(tot)")
                    let lista = elenco
                    if lista.isEmpty {
                        Text(AXIsProcessTrusted() ? T("Nessuna app di messaggi nel Dock", "No messaging apps in the Dock")
                                                  : T("Serve l'Accessibilità (Impostazioni → Permessi)", "Needs Accessibility (Settings → Permissions)"))
                            .font(.system(size: 12)).foregroundStyle(Volta.t3)
                    }
                    HStack(spacing: 4) { ForEach(lista.prefix(5)) { a in icona(a) } }
                    Spacer(minLength: 0)
                    // 29/10: start something new without opening the app first
                    HStack(spacing: 6) {
                        TastoTondo(simbolo: "envelope", nome: T("Nuova email", "New email")) { NSWorkspace.shared.open(URL(string: "mailto:")!) }
                        TastoTondo(simbolo: "message", nome: T("Nuovo messaggio", "New message")) { ApriApp.apri(bundle: "com.apple.MobileSMS", nome: "Messages") }
                        TastoTondo(simbolo: "number", nome: "Slack") { ApriApp.apri(bundle: "com.tinyspeck.slackmacgap", nome: "Slack", web: "https://app.slack.com") }
                        TastoTondo(simbolo: "paperplane", nome: "Lark") { ApriApp.apri(bundle: "com.larksuite.larkApp", nome: "Lark", web: "https://www.larksuite.com") }
                        TastoTondo(simbolo: "moon", nome: T("Full immersion / Non disturbare", "Focus / Do Not Disturb")) {
                            TileOpen.url("x-apple.systempreferences:com.apple.Focus-Settings.extension")
                        }
                        TastoTondo(simbolo: "bell.badge", nome: T("Impostazioni notifiche", "Notification settings")) {
                            TileOpen.url("x-apple.systempreferences:com.apple.Notifications-Settings.extension")
                        }
                    }
                }
            }
            VCard(padding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(T("Notifiche", "Notifications")).font(.system(size: 12, weight: .medium)).foregroundStyle(Volta.t2)
                        Spacer()
                        if !log.items.isEmpty {
                            Button(T("Svuota", "Clear all")) { for i in log.items { log.remove(i.id) } }
                                .buttonStyle(.plain).font(.system(size: 11.5)).foregroundStyle(Volta.t3)
                        }
                    }
                    if log.items.isEmpty {
                        Text(T("Le notifiche che arrivano compaiono qui", "Notifications that come in show up here"))
                            .font(.system(size: 12)).foregroundStyle(Volta.t3)
                    }
                    ForEach(log.items.prefix(3)) { n in
                        HStack(alignment: .top, spacing: 6) {
                            VStack(alignment: .leading, spacing: 1) {
                                HStack {
                                    Text(n.title).font(.system(size: 12, weight: n.seen ? .regular : .medium)).foregroundStyle(Volta.t1).lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(n.date.formatted(date: .omitted, time: .shortened)).font(.system(size: 10.5)).foregroundStyle(Volta.t3)
                                }
                                if !n.body.isEmpty { Text(n.body).font(.system(size: 11)).foregroundStyle(Volta.t2).lineLimit(1) }
                            }
                            Button {
                                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(n.title + (n.body.isEmpty ? "" : "\n" + n.body), forType: .string)
                            } label: { Image(systemName: "doc.on.doc").font(.system(size: 9.5)).foregroundStyle(Volta.t3).frame(width: 16, height: 16) }
                            .buttonStyle(.plain).hint(T("Copia", "Copy"))
                            Button { log.remove(n.id) } label: { Image(systemName: "xmark").font(.system(size: 9)).foregroundStyle(Volta.t3).frame(width: 16, height: 16) }
                            .buttonStyle(.plain).hint(T("Togli", "Dismiss"))
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(width: 310)
        }
        .onAppear { dock.guarda(true) }
        .onDisappear { dock.guarda(false); log.markSeen() }
    }

    /// Apps with something unread first, then the usual messaging apps that are in the Dock.
    private var elenco: [DockBadges.App] {
        let conBadge = CommsLogic.ordina(dock.app.map { (nome: $0.nome, badge: $0.badge) }).compactMap { o in dock.app.first { $0.nome == o.nome } }
        let altre = dock.app.filter { a in a.badge == nil && CommsLogic.note.contains { a.nome.localizedCaseInsensitiveContains($0) } }
        return conBadge + altre
    }

    private func icona(_ a: DockBadges.App) -> some View {
        Button { if let u = a.url { NSWorkspace.shared.openApplication(at: u, configuration: NSWorkspace.OpenConfiguration()) } } label: {
            VStack(spacing: 4) {
                Image(nsImage: a.url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage())
                    .resizable().frame(width: 34, height: 34)
                    .overlay(alignment: .topTrailing) {
                        if let b = a.badge, !b.isEmpty {
                            Text(b).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18).background(Capsule().fill(Color.red))
                                .offset(x: 6, y: -4)
                        }
                    }
                Text(a.nome).font(.system(size: 10.5)).foregroundStyle(Volta.t2).lineLimit(1)
            }
            .frame(width: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hint(T("Apri \(a.nome)", "Open \(a.nome)"))
    }
}

// MARK: - Files

/// The newest files in Downloads, refreshed while the tab is open; and tidying Downloads into folders by kind.
final class DownloadsModel: ObservableObject {
    static let shared = DownloadsModel()
    struct File: Identifiable, Equatable { var id: URL { url }; let url: URL; let data: Date; let byte: Int }
    @Published private(set) var file: [File] = []
    /// The last tidy, to undo it: (where it is now, where it was).
    @Published private(set) var annulla: [(URL, URL)] = []
    private var timer: Timer?
    let cartella = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]

    func guarda(_ on: Bool) {
        timer?.invalidate(); timer = nil
        guard on else { return }
        aggiorna()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.aggiorna() }
    }

    func aggiorna() {
        let chiavi: [URLResourceKey] = [.addedToDirectoryDateKey, .creationDateKey, .fileSizeKey]
        let tutti = (try? FileManager.default.contentsOfDirectory(at: cartella, includingPropertiesForKeys: chiavi, options: [.skipsHiddenFiles])) ?? []
        let nuovi = tutti.compactMap { u -> File? in
            let v = try? u.resourceValues(forKeys: Set(chiavi))
            guard let d = v?.addedToDirectoryDate ?? v?.creationDate else { return nil }
            return File(url: u, data: d, byte: v?.fileSize ?? 0)
        }
        .sorted { $0.data > $1.data }.prefix(4)
        if Array(nuovi) != file { file = Array(nuovi) }
    }

    func cestino(_ f: File) { try? FileManager.default.trashItem(at: f.url, resultingItemURL: nil); aggiorna() }

    /// 29/10: puts the loose files in Downloads into Images, Documents, Archives… after asking. Undo puts them back.
    func riordina() {
        let fm = FileManager.default
        let tutti = (try? fm.contentsOfDirectory(at: cartella, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        let piano = tutti.compactMap { u -> (URL, String)? in
            let dir = (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if dir && RiordinaDownload.cartelle.contains(u.lastPathComponent) { return nil }
            return RiordinaDownload.cartella(u.lastPathComponent, isCartella: dir).map { (u, $0) }
        }
        guard !piano.isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = T("Riordinare i Download?", "Tidy Downloads?")
        let conti = Dictionary(grouping: piano, by: \.1).map { "\($0.key): \($0.value.count)" }.sorted().joined(separator: ", ")
        a.informativeText = T("\(piano.count) file in cartelle per tipo (\(conti)). Puoi annullare subito dopo.",
                              "\(piano.count) files into folders by kind (\(conti)). You can undo it right after.")
        a.addButton(withTitle: T("Riordina", "Tidy")); a.addButton(withTitle: T("Annulla", "Cancel"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        var fatti: [(URL, URL)] = []
        for (u, c) in piano {
            let dest = cartella.appendingPathComponent(c, isDirectory: true)
            try? fm.createDirectory(at: dest, withIntermediateDirectories: true)
            var arrivo = dest.appendingPathComponent(u.lastPathComponent)
            var n = 2
            while fm.fileExists(atPath: arrivo.path) {
                let base = u.deletingPathExtension().lastPathComponent, ext = u.pathExtension
                arrivo = dest.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"); n += 1
            }
            if (try? fm.moveItem(at: u, to: arrivo)) != nil { fatti.append((arrivo, u)) }
        }
        annulla = fatti
        aggiorna()
    }

    func annullaRiordino() {
        for (ora, prima) in annulla where !FileManager.default.fileExists(atPath: prima.path) { try? FileManager.default.moveItem(at: ora, to: prima) }
        annulla = []
        aggiorna()
    }

    /// Free space on the startup disk, e.g. "212 GB free".
    var libero: String? {
        guard let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage else { return nil }
        return T("\(ByteCountFormatter.string(fromByteCount: v, countStyle: .file)) liberi", "\(ByteCountFormatter.string(fromByteCount: v, countStyle: .file)) free")
    }
}

struct FilesTab: View {
    @ObservedObject private var dl = DownloadsModel.shared
    @ObservedObject private var tray = TrayModel.shared

    var body: some View {
        HStack(spacing: 8) {
            VCard(padding: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(T("Download recenti", "Recent downloads")).font(.system(size: 12, weight: .medium)).foregroundStyle(Volta.t2)
                        Spacer()
                        if !dl.annulla.isEmpty {
                            Button(T("Annulla riordino", "Undo tidy")) { dl.annullaRiordino() }
                                .buttonStyle(.plain).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Volta.a2)
                        } else if let l = dl.libero {
                            Text(l).font(.system(size: 11)).foregroundStyle(Volta.t3)
                        }
                    }
                    if dl.file.isEmpty { Text(T("Niente di nuovo", "Nothing new")).font(.system(size: 12)).foregroundStyle(Volta.t3) }
                    ForEach(dl.file) { f in riga(f) }
                    Spacer(minLength: 0)
                }
            }
            GrigliaTasti {
                TastoScheda(simbolo: "arrow.down.circle", titolo: T("Download", "Downloads")) { NSWorkspace.shared.open(dl.cartella) }
                TastoScheda(simbolo: "wand.and.stars", titolo: T("Riordina", "Tidy up"), principale: true) { dl.riordina() }
                TastoScheda(simbolo: "menubar.dock.rectangle", titolo: T("Scrivania", "Desktop")) {
                    NSWorkspace.shared.open(FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0])
                }
                TastoScheda(simbolo: "doc", titolo: T("Documenti", "Documents")) {
                    NSWorkspace.shared.open(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
                }
                TastoScheda(simbolo: "dot.radiowaves.up.forward", titolo: "AirDrop") { IslandActions.airDrop() }
                TastoScheda(simbolo: "icloud", titolo: "iCloud Drive") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs"))
                }
                TastoScheda(simbolo: "tray.and.arrow.down", titolo: tray.files.isEmpty ? T("Ripiano", "Shelf") : T("Ripiano · \(tray.files.count)", "Shelf · \(tray.files.count)")) {
                    tray.scegli()
                }
                TastoScheda(simbolo: "trash", titolo: T("Cestino", "Trash")) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/.Trash"))
                }
            }
            .frame(width: 280)
        }
        .onAppear { dl.guarda(true) }
        .onDisappear { dl.guarda(false) }
    }

    private func riga(_ f: DownloadsModel.File) -> some View {
        HStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: f.url.path)).resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(f.url.lastPathComponent).font(.system(size: 12)).foregroundStyle(Volta.t1).lineLimit(1).truncationMode(.middle)
                Text(ByteCountFormatter.string(fromByteCount: Int64(f.byte), countStyle: .file) + " · " + f.data.formatted(.relative(presentation: .named)))
                    .font(.system(size: 10.5)).foregroundStyle(Volta.t3).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { NSWorkspace.shared.open(f.url) }
            .onDrag { NSItemProvider(contentsOf: f.url) ?? NSItemProvider() }          // drag it straight into another app
            .hint(T("Apri, o trascinalo in un'altra app", "Open, or drag it into another app"))
            TastoTondo(simbolo: "magnifyingglass", nome: T("Mostra nel Finder", "Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([f.url]) }
            TastoTondo(simbolo: "link", nome: T("Copia il percorso", "Copy the path")) {
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(f.url.path, forType: .string)
            }
            TastoTondo(simbolo: "square.and.arrow.up", nome: T("Invia con AirDrop", "Send with AirDrop")) {
                NSSharingService(named: .sendViaAirDrop)?.perform(withItems: [f.url])
            }
            TastoTondo(simbolo: "tray.and.arrow.down", nome: T("Metti sul ripiano", "Put on the shelf")) { TrayModel.shared.add([f.url]) }
            TastoTondo(simbolo: "trash", nome: T("Sposta nel Cestino", "Move to Trash")) { dl.cestino(f) }
        }
    }
}

// MARK: - Now Playing (29/10: the song with every control, and a mixer beside it)

struct MusicTab: View {
    let media: MediaSource?
    let dial: DialStore?
    var body: some View {
        HStack(spacing: 8) {
            if let media { Riproduzione(media: media) }
            else { VCard { Text(T("Nessun lettore musicale", "No music player")).font(.system(size: 14)).foregroundStyle(Volta.t2) } }
            Mixer(dial: dial).frame(width: 250)
        }
    }

    private struct Riproduzione: View {
        @ObservedObject var media: MediaSource

        var body: some View {
            let t = media.track ?? media.last
            let live = media.track != nil
            let suona = live && media.track?.playing == true
            let cols = ArtPalette.colors(media.artwork)
            VCard(glow: suona ? cols[0] : Volta.a2, motion: suona ? cols : nil, padding: 12) {
                HStack(spacing: 14) {
                    Group {
                        if let a = media.artwork, live { Image(nsImage: a).resizable().aspectRatio(contentMode: .fill) }
                        else { LinearGradient(colors: [Volta.a2, Volta.a4], startPoint: .topLeading, endPoint: .bottomTrailing) }
                    }
                    .frame(width: 112, height: 112).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onTapGesture { SchedaMusicaApri.apri(t?.app) }
                    .hint(T("Apri \(t?.app ?? "Spotify")", "Open \(t?.app ?? "Spotify")"))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(suona ? T("In riproduzione", "Now playing") : live ? T("In pausa", "Paused") : T("Ultimo ascoltato", "Last played"))
                            .font(.system(size: 11)).foregroundStyle(Volta.t3)
                        Text(t?.title ?? T("Niente in riproduzione", "Nothing playing")).font(.system(size: 16, weight: .semibold)).foregroundStyle(Volta.t1).lineLimit(1)
                        Text([t?.artist, t?.album].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.system(size: 12)).foregroundStyle(Volta.t2).lineLimit(1)
                        riga
                        Spacer(minLength: 0)
                        if live { ProgressBar(src: media) }
                        HStack(spacing: 6) {
                            tasto("shuffle", 11, T("Casuale", "Shuffle")) { media.command(.shuffle) }.disabled(!live)
                            tasto("gobackward.15", 12, T("Indietro 15 s", "Back 15 s")) { media.command(.skip(-15)) }.disabled(!live)
                            tasto("backward.fill", 13, T("Precedente", "Previous")) { media.command(.previous) }.disabled(!live)
                            Button { live ? media.command(.playPause) : media.resumeLast() } label: {
                                Image(systemName: suona ? "pause.fill" : "play.fill").font(.system(size: 15, weight: .semibold)).foregroundStyle(Volta.primT)
                                    .frame(width: 36, height: 36).background(Circle().fill(Volta.prim)).contentShape(Circle())
                            }
                            .buttonStyle(.plain).hint(suona ? T("Pausa", "Pause") : T("Riproduci", "Play"))
                            tasto("forward.fill", 13, T("Successivo", "Next")) { media.command(.next) }.disabled(!live)
                            tasto("goforward.15", 12, T("Avanti 15 s", "Forward 15 s")) { media.command(.skip(15)) }.disabled(!live)
                            tasto("repeat", 11, T("Ripeti", "Repeat")) { media.command(.repeatMode) }.disabled(!live)
                            Spacer(minLength: 0)
                            tasto("arrow.up.left.and.arrow.down.right", 10, T("Lettore a tutto schermo", "Full screen player")) { FullPlayer.shared.toggle(media: media) }
                        }
                    }
                }
            }
        }

        /// The line being sung, when the song has synced lyrics.
        @ViewBuilder private var riga: some View {
            if case .synced(let righe) = media.lyrics {
                TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                    if let i = LRC.index(at: media.position(at: ctx.date), in: righe) {
                        Text("“\(righe[i].text)”").font(.system(size: 12.5, weight: .medium)).foregroundStyle(Volta.t1.opacity(0.85)).lineLimit(1)
                    }
                }
            }
        }

        private func tasto(_ s: String, _ size: CGFloat, _ nome: String, _ a: @escaping () -> Void) -> some View {
            Button(action: a) {
                Image(systemName: s).font(.system(size: size, weight: .medium)).foregroundStyle(Volta.t1).frame(width: 26, height: 26).contentShape(Rectangle())
            }
            .buttonStyle(.plain).hint(nome)
        }
    }

    /// System volume and mute, each app's own volume (the dial's mixer), and where the sound goes.
    private struct Mixer: View {
        let dial: DialStore?
        @State private var volume: Float = SystemVolume.level
        @State private var muto = SystemVolume.muted
        @State private var uscite: [UsciteAudio.Uscita] = []
        @State private var uscita = UsciteAudio.attuale

        var body: some View {
            VCard(padding: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Mixer").font(.system(size: 12, weight: .medium)).foregroundStyle(Volta.t2)
                        Spacer()
                        Menu {
                            ForEach(uscite) { u in
                                Button((u.id == uscita ? "✓ " : "") + u.nome) { UsciteAudio.scegli(u.id); uscita = u.id }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "hifispeaker").font(.system(size: 10))
                                Text(uscite.first { $0.id == uscita }?.nome ?? T("Uscita", "Output")).font(.system(size: 11)).lineLimit(1)
                            }
                            .foregroundStyle(Volta.t2)
                        }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                        .hint(T("Dove va il suono", "Where the sound goes"))
                    }
                    riga(icona: Image(systemName: muto ? "speaker.slash.fill" : "speaker.wave.2.fill"), nome: T("Sistema", "System"),
                         valore: muto ? 0 : volume, muto: muto,
                         cambia: { volume = $0; SystemVolume.level = $0; if muto { muto = false } },
                         silenzia: { muto.toggle(); SystemVolume.muted = muto })
                    if let dial { AppMixer(store: dial, riga: riga) }
                    Spacer(minLength: 0)
                }
            }
            .onAppear { volume = SystemVolume.level; muto = SystemVolume.muted; uscite = UsciteAudio.elenco(); uscita = UsciteAudio.attuale }
        }

        func riga(icona: Image, nome: String, valore: Float, muto: Bool, cambia: @escaping (Float) -> Void, silenzia: @escaping () -> Void) -> AnyView {
            AnyView(HStack(spacing: 7) {
                Button(action: silenzia) {
                    icona.resizable().scaledToFit().frame(width: 16, height: 16).foregroundStyle(muto ? Night.amber : Volta.t2)
                        .frame(width: 22, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain).hint(muto ? T("Riattiva \(nome)", "Unmute \(nome)") : T("Silenzia \(nome)", "Mute \(nome)"))
                Text(nome).font(.system(size: 11.5)).foregroundStyle(Volta.t1).lineLimit(1).frame(width: 62, alignment: .leading)
                Slider(value: Binding(get: { Double(valore) }, set: { cambia(Float($0)) }), in: 0...1).controlSize(.mini)
                Text("\(Int((valore * 100).rounded()))").font(.system(size: 10.5).monospacedDigit()).foregroundStyle(Volta.t3).frame(width: 24, alignment: .trailing)
            })
        }
    }

    /// The apps playing sound right now, each with its own volume.
    private struct AppMixer: View {
        @ObservedObject var store: DialStore
        @ObservedObject private var icone = IconeApp.shared
        let riga: (Image, String, Float, Bool, @escaping (Float) -> Void, @escaping () -> Void) -> AnyView

        var body: some View {
            Group {
                if store.apps.isEmpty {
                    Text(T("Nessuna app sta suonando", "No app is playing")).font(.system(size: 11)).foregroundStyle(Volta.t3)
                }
                ForEach(store.apps.prefix(3)) { app in
                    let g = store.gain(app.id)
                    let icona = (icone.icona(bundle: app.id) ?? app.icon).map { Image(nsImage: $0) } ?? Image(systemName: "app")
                    riga(icona, app.name, g, g == 0, { store.setGain(app.id, $0) }, { store.setGain(app.id, g == 0 ? 1 : 0) })
                }
                if store.tapError {
                    Text(T("Serve Registrazione audio di sistema", "Needs System Audio Recording")).font(.system(size: 10)).foregroundStyle(Night.amber)
                }
            }
            .onAppear { store.refresh() }
        }
    }
}

enum SchedaMusicaApri {
    static func apri(_ app: String?) {
        ApriApp.apri(bundle: app == "Music" ? "com.apple.Music" : "com.spotify.client", nome: app ?? "Spotify")
    }
}

// MARK: - Meetings

struct MeetingsTab: View {
    @ObservedObject private var cal = CalendarModel.shared
    @State private var bloccato: String?

    var body: some View {
        HStack(spacing: 8) {
            VCard(padding: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    TimelineView(.everyMinute) { ctx in
                        Titoletto(testo: T("Oggi", "Today"), destra: bloccato ?? prossima(ctx.date))
                    }
                    if cal.denied {
                        Text(T("Consenti il Calendario in Impostazioni di Sistema", "Allow Calendar in System Settings")).font(.system(size: 12)).foregroundStyle(Night.amber)
                    } else if cal.oggi.isEmpty {
                        Text(T("Niente altro oggi", "Nothing else today")).font(.system(size: 12)).foregroundStyle(Volta.t3)
                    }
                    ForEach(Array(cal.oggi.prefix(4).enumerated()), id: \.offset) { _, e in riga(e) }
                    Spacer(minLength: 0)
                }
            }
            GrigliaTasti {
                TastoScheda(simbolo: "video.fill", titolo: "Google Meet", principale: true) { NSWorkspace.shared.open(URL(string: "https://meet.new")!) }
                TastoScheda(simbolo: "video", titolo: "Zoom") { NSWorkspace.shared.open(URL(string: "https://zoom.us/start/videomeeting")!) }
                TastoScheda(simbolo: "note.text", titolo: "Granola") { ApriApp.apri(bundle: "com.granola.app", nome: "Granola", web: "https://granola.ai") }
                TastoScheda(simbolo: "brain.head.profile", titolo: T("Focus 30 min", "Focus 30 min")) { blocca(30) }
                TastoScheda(simbolo: "calendar", titolo: T("Calendario", "Calendar")) { TileOpen.app("Calendar") }
                TastoScheda(simbolo: "globe", titolo: "Google Cal") { NSWorkspace.shared.open(URL(string: "https://calendar.google.com")!) }
                TastoScheda(simbolo: "calendar.badge.plus", titolo: T("Nuovo evento", "New event")) {
                    NSWorkspace.shared.open(URL(string: "https://calendar.google.com/calendar/r/eventedit")!)
                }
                TastoScheda(simbolo: "hourglass", titolo: T("Focus 1 h", "Focus 1 h")) { blocca(60) }
            }
            .frame(width: 280)
        }
        .onAppear { cal.refresh() }
    }

    /// "Standup in 12 min", or nil when there's no meeting coming today.
    private func prossima(_ ora: Date) -> String? {
        guard let e = cal.oggi.first(where: { !$0.allDay && $0.start > ora }) else { return nil }
        let m = Int(e.start.timeIntervalSince(ora) / 60)
        let quando = m < 60 ? T("tra \(max(1, m)) min", "in \(max(1, m)) min") : T("alle \(e.start.formatted(date: .omitted, time: .shortened))", "at \(e.start.formatted(date: .omitted, time: .shortened))")
        return "\(e.title.prefix(18)) \(quando)"
    }

    private func blocca(_ minuti: Int) {
        bloccato = cal.bloccaFocus(minuti: minuti) ? T("Focus fino alle \(Date().addingTimeInterval(Double(minuti * 60)).formatted(date: .omitted, time: .shortened))",
                                                         "Focus until \(Date().addingTimeInterval(Double(minuti * 60)).formatted(date: .omitted, time: .shortened))")
                                                  : T("Serve il Calendario", "Needs Calendar access")
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { bloccato = nil }
    }

    private func riga(_ e: CalendarModel.Next) -> some View {
        let adesso = !e.allDay && e.start <= Date() && e.end > Date()
        return HStack(spacing: 6) {
            Text(e.allDay ? T("Giorno", "All day") : e.start.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11.5).monospacedDigit()).foregroundStyle(adesso ? Volta.a2 : Volta.t3).frame(width: 56, alignment: .leading)
            Text(e.title).font(.system(size: 12.5, weight: adesso ? .semibold : .regular)).foregroundStyle(Volta.t1).lineLimit(1)
            Spacer(minLength: 4)
            if let m = Invitati.mail(e.invitati, oggetto: e.title) {
                TastoTondo(simbolo: "envelope", nome: T("Scrivi agli invitati", "Email the attendees")) { NSWorkspace.shared.open(m) }
            }
            if let link = e.link {
                TastoTondo(simbolo: "link", nome: T("Copia il link", "Copy the link")) {
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(link.absoluteString, forType: .string)
                }
                Button { NSWorkspace.shared.open(link) } label: {
                    Text(T("Entra", "Join")).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).frame(height: 22).background(Capsule().fill(Volta.a2)).contentShape(Capsule())
                }
                .buttonStyle(.plain).hint(T("Entra nella riunione", "Join the meeting"))
            }
        }
        .frame(height: 26)
    }
}

// MARK: - Notion

/// Pages pinned to the Notion tab: a name and a link, saved in Pulsar's settings.
final class NotionPins: ObservableObject {
    static let shared = NotionPins()
    struct Pagina: Codable, Identifiable, Equatable { var id: String { link }; var nome: String; var link: String }
    @Published private(set) var pagine: [Pagina] = {
        (Impostazioni.data(.notionPagine)).flatMap { try? JSONDecoder().decode([Pagina].self, from: $0) } ?? []
    }()

    private func salva() { Impostazioni.set(try? JSONEncoder().encode(pagine), .notionPagine) }

    func aggiungi() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = T("Fissa una pagina di Notion", "Pin a Notion page")
        a.informativeText = T("In Notion: Condividi → Copia link, poi incollalo qui.", "In Notion: Share → Copy link, then paste it here.")
        let link = NSTextField(frame: NSRect(x: 0, y: 30, width: 320, height: 24)); link.placeholderString = "https://www.notion.so/…"
        if let c = NSPasteboard.general.string(forType: .string), NotionLinks.app(c) != nil { link.stringValue = c }    // a copied link, ready
        let nome = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24)); nome.placeholderString = T("Nome (facoltativo)", "Name (optional)")
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 54)); v.addSubview(link); v.addSubview(nome)
        a.accessoryView = v
        a.window.initialFirstResponder = link
        a.addButton(withTitle: T("Fissa", "Pin")); a.addButton(withTitle: T("Annulla", "Cancel"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let l = link.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard NotionLinks.app(l) != nil else { return }
        let n = nome.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        pagine.removeAll { $0.link == l }
        pagine.append(Pagina(nome: n.isEmpty ? NotionLinks.nome(l) : n, link: l))
        salva()
    }

    func togli(_ p: Pagina) { pagine.removeAll { $0 == p }; salva() }

    func rinomina(_ p: Pagina) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert(); a.messageText = T("Rinomina", "Rename")
        let f = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24)); f.stringValue = p.nome
        a.accessoryView = f
        a.addButton(withTitle: "OK"); a.addButton(withTitle: T("Annulla", "Cancel"))
        guard a.runModal() == .alertFirstButtonReturn, let i = pagine.firstIndex(of: p) else { return }
        let n = f.stringValue.trimmingCharacters(in: .whitespaces)
        if !n.isEmpty { pagine[i].nome = n; salva() }
    }

    static var haApp: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: "notion.id") != nil }

    static func apri(_ link: String) {
        if haApp, let u = NotionLinks.app(link) { NSWorkspace.shared.open(u) }
        else if let u = URL(string: link) { NSWorkspace.shared.open(u) }
    }

    /// 29/10: a quick note: copied, then a new page opens to paste it into (Notion has no way in without its API).
    static func notaVeloce() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = T("Nota veloce per Notion", "Quick note for Notion")
        a.informativeText = T("La copio e apro una pagina nuova: incolla con ⌘V.", "I'll copy it and open a new page: paste with ⌘V.")
        let sv = NSScrollView(frame: NSRect(x: 0, y: 0, width: 340, height: 110)); sv.hasVerticalScroller = true; sv.borderType = .bezelBorder
        let tv = NSTextView(frame: sv.bounds); tv.isRichText = false; tv.font = .systemFont(ofSize: 13); tv.autoresizingMask = [.width, .height]
        sv.documentView = tv
        a.accessoryView = sv
        a.window.initialFirstResponder = tv
        a.addButton(withTitle: T("Copia e apri", "Copy and open")); a.addButton(withTitle: T("Annulla", "Cancel"))
        guard a.runModal() == .alertFirstButtonReturn, !tv.string.isEmpty else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(tv.string, forType: .string)
        NSWorkspace.shared.open(URL(string: "https://www.notion.so/new")!)
    }
}

struct NotionTab: View {
    @ObservedObject private var pins = NotionPins.shared

    var body: some View {
        HStack(spacing: 8) {
            VCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Titoletto(testo: T("Pagine fissate", "Pinned pages"), destra: pins.pagine.isEmpty ? nil : T("clic destro: altro", "right-click: more"))
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 6)], alignment: .leading, spacing: 6) {
                            ForEach(pins.pagine) { p in
                                Button { NotionPins.apri(p.link) } label: {
                                    HStack(spacing: 7) {
                                        Image(systemName: "doc.text").font(.system(size: 11)).foregroundStyle(Volta.t2)
                                        Text(p.nome).font(.system(size: 12.5)).foregroundStyle(Volta.t1).lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 10).frame(height: 30)
                                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Volta.card2))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(T("Apri nel browser", "Open in browser")) { if let u = URL(string: p.link) { NSWorkspace.shared.open(u) } }
                                    Button(T("Copia il link", "Copy link")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(p.link, forType: .string) }
                                    Button(T("Rinomina", "Rename")) { pins.rinomina(p) }
                                    Button(T("Togli", "Unpin")) { pins.togli(p) }
                                }
                                .hint(T("Apri in Notion", "Open in Notion"))
                            }
                            Button { pins.aggiungi() } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "pin").font(.system(size: 11))
                                    Text(T("Fissa una pagina", "Pin a page")).font(.system(size: 12.5))
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(Volta.t2)
                                .padding(.horizontal, 10).frame(height: 30)
                                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Volta.t3.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .hint(T("Copia il link di una pagina in Notion, poi clicca qui", "Copy a page's link in Notion, then click here"))
                        }
                    }
                }
            }
            GrigliaTasti {
                TastoScheda(simbolo: "plus", titolo: T("Nuova pagina", "New page"), principale: true) { NSWorkspace.shared.open(URL(string: "https://www.notion.so/new")!) }
                TastoScheda(simbolo: "square.and.pencil", titolo: T("Nota veloce", "Quick note")) { NotionPins.notaVeloce() }
                TastoScheda(simbolo: "n.square", titolo: "Notion") { ApriApp.apri(bundle: "notion.id", nome: "Notion", web: "https://www.notion.so") }
                TastoScheda(simbolo: "sparkles", titolo: "Notion AI") { NSWorkspace.shared.open(URL(string: "https://www.notion.so/ai")!) }
                TastoScheda(simbolo: "calendar", titolo: T("Calendario", "Calendar")) { ApriApp.apri(bundle: "com.cron.electron", nome: "Notion Calendar", web: "https://calendar.notion.so") }
                TastoScheda(simbolo: "envelope", titolo: "Mail") { ApriApp.apri(bundle: "notion.mail.id", nome: "Notion Mail", web: "https://mail.notion.so") }
                TastoScheda(simbolo: "doc.on.clipboard", titolo: T("Fissa copiato", "Pin copied")) { pins.aggiungi() }
                TastoScheda(simbolo: "globe", titolo: T("Nel browser", "In browser")) { NSWorkspace.shared.open(URL(string: "https://www.notion.so")!) }
            }
            .frame(width: 280)
        }
    }
}
