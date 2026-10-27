// 27/10: the To-do tile synced with Google Tasks ("My Tasks"), both ways: add or tick off on either side.
// You bring your own Google OAuth client (Desktop app), so nothing goes through anyone else's server.
// Network: only Google (accounts.google.com, oauth2.googleapis.com, tasks.googleapis.com), only while connected,
// every 2 minutes and right after you add or tick off something. The login is kept in the Keychain.
// The pure parts (addresses, parsing, what to change) are in google-tasks-logica.swift.
import AppKit
import Network
import Security

final class GoogleTasks: ObservableObject {
    static let shared = GoogleTasks()

    enum Stato: Equatable { case scollegato, inAttesa, collegato, errore(String) }
    @Published private(set) var stato: Stato = .scollegato

    private var token: GoogleTasksAPI.Token?
    private var timer: Timer?
    private var listener: NWListener?
    private var sincronizza = false
    private var ancora = false
    private let session = URLSession(configuration: .ephemeral)

    var clientID: String { Impostazioni.string(.googleClientID) ?? "" }
    private var clientSecret: String { Impostazioni.string(.googleClientSecret) ?? "" }
    /// Ticked off here, not yet confirmed by Google: retried on every sync, never added back meanwhile.
    private var daCompletare: [String] {
        get { Impostazioni.stringArray(.googleDaCompletare) ?? [] }
        set { Impostazioni.set(newValue, .googleDaCompletare) }
    }

    /// At launch: if a login is saved, start syncing.
    func avvia() {
        guard !clientID.isEmpty, Portachiavi.leggi() != nil else { return }
        stato = .collegato
        AnimaCose.shared.start()
        pianifica()
        sync()
    }

    // MARK: collegare

    /// Settings → Island → Google Tasks → Connect: asks for the client, then opens Google's sign-in in the browser.
    func collega() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = T("Collega Google Tasks", "Connect Google Tasks")
        a.informativeText = T("Incolla l'ID client e il segreto client della tua app OAuth di Google (tipo App desktop). Poi accedi nel browser.",
                              "Paste the Client ID and Client secret of your Google OAuth app (type Desktop app). Then sign in in your browser.")
        let id = NSTextField(frame: NSRect(x: 0, y: 30, width: 320, height: 24)); id.placeholderString = "Client ID"; id.stringValue = clientID
        let sec = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24)); sec.placeholderString = "Client secret"; sec.stringValue = clientSecret
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 54)); v.addSubview(id); v.addSubview(sec)
        a.accessoryView = v
        a.addButton(withTitle: T("Accedi…", "Sign in…")); a.addButton(withTitle: T("Annulla", "Cancel"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let cid = id.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let cs = sec.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cid.isEmpty else { return }
        Impostazioni.set(cid, .googleClientID)
        Impostazioni.set(cs, .googleClientSecret)
        accedi()
    }

    func scollega() {
        timer?.invalidate(); timer = nil
        listener?.cancel(); listener = nil
        token = nil
        Portachiavi.cancella()
        daCompletare = []
        stato = .scollegato
    }

    /// A one-off local page on 127.0.0.1 receives Google's answer; the browser shows "you can close this tab".
    private func accedi() {
        listener?.cancel()
        let verifier = GoogleTasksAPI.verifier()
        let state = UUID().uuidString
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
        guard let l = try? NWListener(using: params) else { stato = .errore(T("Pagina locale non avviata", "Couldn't start the local page")); return }
        listener = l
        stato = .inAttesa
        l.newConnectionHandler = { [weak self] c in self?.ricevi(c, verifier: verifier, state: state) }
        l.stateUpdateHandler = { [weak self] s in
            guard let self, case .ready = s, let port = l.port?.rawValue else { return }
            self.redirect = "http://127.0.0.1:\(port)"
            NSWorkspace.shared.open(GoogleTasksAPI.signInURL(clientID: self.clientID, redirect: self.redirect, verifier: verifier, state: state))
        }
        l.start(queue: .main)
        // nobody signs in for 5 minutes: give up quietly
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
            guard let self, self.listener === l, self.stato == .inAttesa else { return }
            l.cancel(); self.listener = nil; self.stato = .scollegato
        }
    }

    private func ricevi(_ c: NWConnection, verifier: String, state: String) {
        c.start(queue: .main)
        c.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            guard let self else { return }
            let line = data.flatMap { String(data: $0, encoding: .utf8) }?.components(separatedBy: "\r\n").first ?? ""
            let esito = GoogleTasksAPI.redirect(requestLine: line, state: state)
            let ok = { if case .success? = esito { return true } else { return false } }()
            let testo = ok ? T("Pulsar è collegato a Google Tasks. Puoi chiudere questa scheda.", "Pulsar is connected to Google Tasks. You can close this tab.")
                           : T("Accesso non riuscito. Torna a Pulsar e riprova.", "Sign-in didn't work. Go back to Pulsar and try again.")
            let html = "<html><body style=\"font-family:-apple-system;padding:40px\">\(testo)</body></html>"
            let risposta = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
            c.send(content: Data(risposta.utf8), completion: .contentProcessed { _ in c.cancel() })
            guard let esito else { return }                       // favicon and the like
            self.listener?.cancel(); self.listener = nil
            switch esito {
            case .success(let code):
                self.scambia(code: code, verifier: verifier, redirect: self.redirect)
            case .failure:
                self.stato = .errore(T("Accesso rifiutato", "Sign-in refused"))
            }
        }
    }

    /// The local page's address; the code exchange must name the same one, port included.
    private var redirect = ""

    private func scambia(code: String, verifier: String, redirect: String) {
        var r = URLRequest(url: GoogleTasksAPI.tokenURL)
        r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        r.httpBody = GoogleTasksAPI.form([("code", code), ("client_id", clientID), ("client_secret", clientSecret),
                                          ("redirect_uri", redirect), ("grant_type", "authorization_code"), ("code_verifier", verifier)])
        session.dataTask(with: r) { [weak self] d, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let d, let t = GoogleTasksAPI.token(d, now: Date()), let refresh = t.refresh else {
                    self.stato = .errore(T("Google non ha dato l'accesso", "Google didn't grant access")); return
                }
                Portachiavi.salva(refresh)
                self.token = t
                self.stato = .collegato
                AnimaCose.shared.start()
                self.pianifica()
                self.sync()
            }
        }.resume()
    }

    // MARK: sincronizzare

    private func pianifica() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in self?.sync() }
    }

    /// Reads Google's list, applies the differences to the To-do list, sends what Google is missing.
    func sync() {
        guard stato == .collegato else { return }
        if sincronizza { ancora = true; return }
        sincronizza = true
        conToken { [weak self] access in
            guard let self else { return }
            guard let access else { self.fine(); return }
            // 1. finish what was ticked off here
            self.completaInSospeso(access) {
                // 2. read Google
                var c = URLComponents(url: GoogleTasksAPI.tasksURL, resolvingAgainstBaseURL: false)!
                c.queryItems = [.init(name: "showCompleted", value: "false"), .init(name: "maxResults", value: "100")]
                self.richiesta(URLRequest(url: c.url!), access) { d in
                    guard let d, let remote = GoogleTasksAPI.tasks(d) else { self.fine(); return }
                    let cose = AnimaCose.shared
                    let locali = cose.todo.map { TasksSync.Local(id: $0.id, text: $0.testo, done: $0.fatto, gid: $0.gid) }
                    let piano = TasksSync.plan(local: locali, remote: remote, completing: Set(self.daCompletare))
                    cose.applicaGoogle(piano)
                    // 3. create in Google what only the To-do list has, one at a time
                    self.crea(piano.createRemote, access) { self.fine() }
                }
            }
        }
    }

    private func fine() {
        sincronizza = false
        if ancora { ancora = false; DispatchQueue.main.async { self.sync() } }
    }

    /// Called by AnimaCose when you tick off an item that came from (or went to) Google.
    func completata(gid: String) {
        guard stato == .collegato else { return }
        if !daCompletare.contains(gid) { daCompletare.append(gid) }
        sync()
    }

    private func completaInSospeso(_ access: String, _ poi: @escaping () -> Void) {
        guard let gid = daCompletare.first else { poi(); return }
        var r = URLRequest(url: GoogleTasksAPI.tasksURL.appendingPathComponent(gid))
        r.httpMethod = "PATCH"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = Data(#"{"status":"completed"}"#.utf8)
        richiesta(r, access, accetta404: true) { [weak self] d in
            guard let self else { return }
            guard d != nil else { poi(); return }                  // offline: try again next time
            self.daCompletare.removeAll { $0 == gid }
            self.completaInSospeso(access, poi)
        }
    }

    private func crea(_ ids: [String], _ access: String, _ poi: @escaping () -> Void) {
        guard let id = ids.first else { poi(); return }
        guard let t = AnimaCose.shared.todo.first(where: { $0.id == id }), t.gid == nil, !t.fatto else { crea(Array(ids.dropFirst()), access, poi); return }
        var r = URLRequest(url: GoogleTasksAPI.tasksURL)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["title": t.testo])
        richiesta(r, access) { [weak self] d in
            if let d, let gid = GoogleTasksAPI.createdID(d) { AnimaCose.shared.collegaGoogle(id, gid: gid) }
            self?.crea(Array(ids.dropFirst()), access, poi)
        }
    }

    // MARK: rete

    /// A valid access token, refreshed with the saved login when it has expired. Nil if that fails.
    private func conToken(_ f: @escaping (String?) -> Void) {
        if let t = token, t.expires > Date() { f(t.access); return }
        guard let refresh = Portachiavi.leggi() else { stato = .scollegato; f(nil); return }
        var r = URLRequest(url: GoogleTasksAPI.tokenURL)
        r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        r.httpBody = GoogleTasksAPI.form([("client_id", clientID), ("client_secret", clientSecret),
                                          ("refresh_token", refresh), ("grant_type", "refresh_token")])
        session.dataTask(with: r) { [weak self] d, resp, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let d, let t = GoogleTasksAPI.token(d, now: Date()) { self.token = t; f(t.access); return }
                // 400 = the login was revoked or expired: ask to connect again. Anything else: offline, try later.
                if (resp as? HTTPURLResponse)?.statusCode == 400 {
                    self.stato = .errore(T("Collega di nuovo", "Connect again")); self.timer?.invalidate()
                }
                f(nil)
            }
        }.resume()
    }

    /// Data on success (2xx; also 404 when asked, for a task already gone), nil otherwise. Answers on the main queue.
    private func richiesta(_ r: URLRequest, _ access: String, accetta404: Bool = false, _ f: @escaping (Data?) -> Void) {
        var r = r
        r.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 20
        session.dataTask(with: r) { d, resp, _ in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let ok = (200..<300).contains(code) || (accetta404 && code == 404)
            DispatchQueue.main.async { f(ok ? (d ?? Data()) : nil) }
        }.resume()
    }
}

/// The Google login (refresh token) in the login Keychain, readable only by Pulsar.
enum Portachiavi {
    private static let servizio = "Pulsar Google Tasks"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: servizio, kSecAttrAccount as String: "refresh"]
    }

    static func salva(_ s: String) {
        SecItemDelete(query as CFDictionary)
        var q = query
        q[kSecValueData as String] = Data(s.utf8)
        SecItemAdd(q as CFDictionary, nil)
    }

    static func leggi() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func cancella() { SecItemDelete(query as CFDictionary) }
}
