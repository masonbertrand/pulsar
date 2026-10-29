// 29/10, the user: "the Notion tab should be my to-do tasks". The tab is now To-do: Pulsar's own list (the same as the
// To-do tile) until Notion is connected, then the tasks of a Notion database: tick them off (Done in Notion), add new
// ones, click to open them. Connecting takes a Notion integration key (notion.so/my-integrations) and the database's
// link, once; the key is kept in the Keychain. Network: api.notion.com only, only while connected and the tab is open.
// Reading Notion's answers is in schede-logica.swift (NotionTasks), tested.
import SwiftUI
import AppKit
import Security

/// A secret in the login Keychain, readable only by Pulsar.
enum Segreto {
    private static func q(_ servizio: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: servizio, kSecAttrAccount as String: "pulsar"]
    }
    static func salva(_ s: String, _ servizio: String) {
        SecItemDelete(q(servizio) as CFDictionary)
        var a = q(servizio); a[kSecValueData as String] = Data(s.utf8)
        SecItemAdd(a as CFDictionary, nil)
    }
    static func leggi(_ servizio: String) -> String? {
        var a = q(servizio); a[kSecReturnData as String] = true; a[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(a as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func cancella(_ servizio: String) { SecItemDelete(q(servizio) as CFDictionary) }
}

final class NotionTodo: ObservableObject {
    static let shared = NotionTodo()
    private static let servizio = "Pulsar Notion"

    enum Stato: Equatable { case scollegato, carica, pronto, errore(String) }
    @Published private(set) var stato: Stato = .scollegato
    @Published private(set) var compiti: [NotionTasks.Compito] = []
    private var schema: NotionTasks.Schema?
    private let session = URLSession(configuration: .ephemeral)

    var database: String? { Impostazioni.string(.notionDatabase) }
    var collegato: Bool { database != nil && Segreto.leggi(Self.servizio) != nil }

    init() { if collegato { stato = .carica } }

    /// Opens Notion's integrations page, then asks for the key and the database link.
    func collega() {
        NSWorkspace.shared.open(URL(string: "https://www.notion.so/my-integrations")!)
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = T("Collega le tue cose da fare di Notion", "Connect your Notion to-dos")
        a.informativeText = T("1. Nella pagina che si è aperta crea un'integrazione interna e copia la sua chiave segreta.\n2. Apri il database delle cose da fare → ··· → Connessioni → aggiungi l'integrazione.\n3. Incolla qui la chiave e il link del database.",
                              "1. On the page that just opened, create an internal integration and copy its secret key.\n2. Open your to-do database → ··· → Connections → add the integration.\n3. Paste the key and the database's link here.")
        let chiave = NSSecureTextField(frame: NSRect(x: 0, y: 30, width: 340, height: 24)); chiave.placeholderString = T("Chiave segreta (ntn_…)", "Secret key (ntn_…)")
        let link = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24)); link.placeholderString = T("Link del database", "Database link")
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 54)); v.addSubview(chiave); v.addSubview(link)
        a.accessoryView = v; a.window.initialFirstResponder = chiave
        a.addButton(withTitle: T("Collega", "Connect")); a.addButton(withTitle: T("Annulla", "Cancel"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let k = chiave.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty, let db = NotionTasks.idDatabase(link.stringValue) else {
            stato = .errore(T("Chiave o link non validi", "The key or the link isn't valid")); return
        }
        Segreto.salva(k, Self.servizio)
        Impostazioni.set(db, .notionDatabase)
        schema = nil
        carica()
    }

    func scollega() {
        Segreto.cancella(Self.servizio)
        Impostazioni.set(nil, .notionDatabase)
        schema = nil; compiti = []; stato = .scollegato
    }

    /// Reads the database's shape once, then its tasks: open ones first, a few done ones after.
    func carica() {
        guard let db = database else { stato = .scollegato; return }
        if compiti.isEmpty { stato = .carica }
        func dopoSchema(_ s: NotionTasks.Schema) {
            richiesta("POST", "databases/\(db)/query", ["page_size": 50, "sorts": [["timestamp": "created_time", "direction": "descending"]]]) { [weak self] d, errore in
                guard let self else { return }
                guard let d else { self.stato = .errore(errore); return }
                let tutti = NotionTasks.compiti(d, schema: s)
                self.compiti = tutti.filter { !$0.fatto } + tutti.filter(\.fatto).prefix(3)
                self.stato = .pronto
            }
        }
        if let s = schema { dopoSchema(s); return }
        richiesta("GET", "databases/\(db)", nil) { [weak self] d, errore in
            guard let self else { return }
            guard let d, let s = NotionTasks.schema(d) else { self.stato = .errore(errore.isEmpty ? T("Database non leggibile", "Can't read the database") : errore); return }
            self.schema = s
            dopoSchema(s)
        }
    }

    /// Ticks a task off (or back on) in Notion; the list changes straight away.
    func cambia(_ c: NotionTasks.Compito) {
        guard let s = schema else { return }
        let valore: [String: Any]
        switch s.fatto {
        case .casella(let n): valore = [n: ["checkbox": !c.fatto]]
        case .stato(let n, let ok): valore = [n: ["status": ["name": c.fatto ? "Not started" : ok]]]
        case .nessuno: return
        }
        if let i = compiti.firstIndex(of: c) { compiti[i].fatto.toggle() }
        richiesta("PATCH", "pages/\(c.id)", ["properties": valore]) { [weak self] d, _ in if d == nil { self?.carica() } }
    }

    func aggiungi(_ testo: String) {
        guard let db = database, let s = schema else { return }
        richiesta("POST", "pages", ["parent": ["database_id": db], "properties": [s.titolo: ["title": [["text": ["content": testo]]]]]]) { [weak self] _, _ in
            self?.carica()
        }
    }

    /// Answers on the main queue: the data, or nil and a short reason.
    private func richiesta(_ metodo: String, _ percorso: String, _ corpo: [String: Any]?, _ f: @escaping (Data?, String) -> Void) {
        guard let k = Segreto.leggi(Self.servizio), let u = URL(string: "https://api.notion.com/v1/\(percorso)") else { f(nil, T("Non collegato", "Not connected")); return }
        var r = URLRequest(url: u, timeoutInterval: 15)
        r.httpMethod = metodo
        r.setValue("Bearer \(k)", forHTTPHeaderField: "Authorization")
        r.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let corpo { r.httpBody = try? JSONSerialization.data(withJSONObject: corpo) }
        session.dataTask(with: r) { d, resp, _ in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let ok = (200..<300).contains(code)
            let perche = code == 401 ? T("Chiave non valida: ricollega", "Key not valid: connect again")
                       : code == 404 ? T("Database non condiviso con l'integrazione", "Database not shared with the integration")
                       : code == 0 ? T("Offline", "Offline") : T("Notion ha risposto \(code)", "Notion answered \(code)")
            DispatchQueue.main.async { f(ok ? d : nil, ok ? "" : perche) }
        }.resume()
    }
}

struct TodoTab: View {
    @ObservedObject var model: IslandModel
    @ObservedObject private var notion = NotionTodo.shared
    @ObservedObject private var cose = AnimaCose.shared
    @State private var nuovo = ""

    var body: some View {
        HStack(spacing: 8) {
            VCard(padding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(notion.collegato ? T("Da fare · Notion", "To-do · Notion") : T("Da fare", "To-do")).font(.system(size: 12, weight: .medium)).foregroundStyle(Volta.t2)
                        Spacer()
                        if case .errore(let e) = notion.stato {
                            Button { notion.collegato ? notion.carica() : notion.collega() } label: {
                                Label(e, systemImage: "exclamationmark.triangle").font(.system(size: 11)).foregroundStyle(Night.amber).lineLimit(1)
                            }
                            .buttonStyle(.plain).hint(T("Riprova", "Try again"))
                        } else if notion.stato == .carica {
                            ProgressView().controlSize(.mini)
                        }
                    }
                    // type a task and press Return
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 13)).foregroundStyle(Volta.a2)
                        TextField(T("Aggiungi una cosa da fare…", "Add a task…"), text: $nuovo)
                            .textFieldStyle(.plain).font(.system(size: 12.5)).foregroundStyle(Volta.t1)
                            .onSubmit { aggiungi() }
                    }
                    .padding(.horizontal, 10).frame(height: 28).background(Capsule().fill(Volta.card2))
                    .onChange(of: nuovo) { _, v in model.trattiene = !v.isEmpty }
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 2) {
                            if notion.collegato {
                                ForEach(notion.compiti, id: \.id) { c in
                                    riga(c.titolo, fatto: c.fatto, extra: c.scadenza.map { String($0.prefix(10)) },
                                         spunta: { notion.cambia(c) }, apri: { if let u = c.url.flatMap(URL.init(string:)) { NSWorkspace.shared.open(u) } })
                                }
                                if notion.compiti.isEmpty && notion.stato == .pronto { vuoto }
                            } else {
                                ForEach(cose.aperte) { t in riga(t.testo, fatto: t.fatto, extra: nil, spunta: { cose.spunta(t) }, apri: nil) }
                                if cose.aperte.isEmpty { vuoto }
                            }
                        }
                    }
                }
            }
            GrigliaTastiTodo {
                if notion.collegato {
                    TastoTodo(simbolo: "arrow.clockwise", titolo: T("Aggiorna", "Refresh")) { notion.carica() }
                    TastoTodo(simbolo: "tablecells", titolo: T("Database", "Database")) {
                        if let db = notion.database { NotionPins.apri("https://www.notion.so/\(db)") }
                    }
                } else {
                    TastoTodo(simbolo: "link", titolo: T("Collega Notion", "Connect Notion"), principale: true) { notion.collega() }
                    TastoTodo(simbolo: "square.and.pencil", titolo: T("Nota veloce", "Quick note")) { NotionPins.notaVeloce() }
                }
                TastoTodo(simbolo: "n.square", titolo: "Notion") { ApriApp.apri(bundle: "notion.id", nome: "Notion", web: "https://www.notion.so") }
                TastoTodo(simbolo: "plus", titolo: T("Nuova pagina", "New page")) { NSWorkspace.shared.open(URL(string: "https://www.notion.so/new")!) }
                TastoTodo(simbolo: "calendar", titolo: T("Calendario", "Calendar")) { ApriApp.apri(bundle: "com.cron.electron", nome: "Notion Calendar", web: "https://calendar.notion.so") }
                TastoTodo(simbolo: "sparkles", titolo: "Notion AI") { NSWorkspace.shared.open(URL(string: "https://www.notion.so/ai")!) }
                if notion.collegato {
                    TastoTodo(simbolo: "xmark.circle", titolo: T("Scollega", "Disconnect")) { notion.scollega() }
                }
            }
            .frame(width: 280)
        }
        .onAppear { if notion.collegato { notion.carica() } else { cose.start() } }
    }

    private var vuoto: some View {
        Text(T("Niente da fare. Scrivine una qui sopra.", "Nothing to do. Type one above."))
            .font(.system(size: 12)).foregroundStyle(Volta.t3).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
    }

    private func aggiungi() {
        let t = nuovo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if notion.collegato { notion.aggiungi(t) } else { cose.start(); cose.aggiungi(t) }
        nuovo = ""
        model.trattiene = false
    }

    private func riga(_ testo: String, fatto: Bool, extra: String?, spunta: @escaping () -> Void, apri: (() -> Void)?) -> some View {
        HStack(spacing: 8) {
            Button(action: spunta) {
                Image(systemName: fatto ? "checkmark.circle.fill" : "circle").font(.system(size: 14))
                    .foregroundStyle(fatto ? Volta.a2 : Volta.t3).frame(width: 20, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.plain).hint(fatto ? T("Riapri", "Mark not done") : T("Fatto", "Mark done"))
            Text(testo).font(.system(size: 12.5)).foregroundStyle(fatto ? Volta.t3 : Volta.t1).strikethrough(fatto).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { apri?() }
            if let extra { Text(extra).font(.system(size: 10.5).monospacedDigit()).foregroundStyle(Volta.t3) }
            if apri != nil { Image(systemName: "arrow.up.forward").font(.system(size: 9)).foregroundStyle(Volta.t3) }
        }
        .frame(height: 24)
    }
}

/// The right-hand buttons (same look as the other tabs').
private struct GrigliaTastiTodo<C: View>: View {
    @ViewBuilder let c: () -> C
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) { c() }
    }
}

private struct TastoTodo: View {
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
