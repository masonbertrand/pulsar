// 27/10: Google Tasks for the To-do tile, the parts with no network or interface: the sign-in addresses (OAuth with PKCE,
// for a desktop app), reading Google's answers, and what a sync has to change on each side. Tested in tests/.
import Foundation
import CryptoKit

enum GoogleTasksAPI {
    static let scope = "https://www.googleapis.com/auth/tasks"
    static let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    /// The user's default list ("My Tasks").
    static let tasksURL = URL(string: "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks")!

    /// A random code verifier, 43 to 128 characters from the allowed set (RFC 7636).
    static func verifier() -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return String((0..<64).map { _ in chars.randomElement()! })
    }

    static func challenge(_ verifier: String) -> String {
        base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func base64url(_ d: Data) -> String {
        d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// The page that asks you to allow Pulsar; Google sends you back to `redirect` with a code.
    static func signInURL(clientID: String, redirect: String, verifier: String, state: String) -> URL {
        var c = URLComponents(string: authURL)!
        c.queryItems = [
            .init(name: "client_id", value: clientID), .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"), .init(name: "scope", value: scope),
            .init(name: "code_challenge", value: challenge(verifier)), .init(name: "code_challenge_method", value: "S256"),
            .init(name: "access_type", value: "offline"), .init(name: "prompt", value: "consent"), .init(name: "state", value: state),
        ]
        return c.url!
    }

    /// The first line of the browser's request to the local page, e.g. `GET /?state=x&code=y HTTP/1.1`.
    /// The code if the state matches, an error if Google refused, nil if it's not the redirect at all.
    static func redirect(requestLine: String, state: String) -> Result<String, RedirectError>? {
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET", let c = URLComponents(string: "http://127.0.0.1" + parts[1]),
              let items = c.queryItems else { return nil }
        func q(_ n: String) -> String? { items.first { $0.name == n }?.value }
        if let e = q("error") { return .failure(.refused(e)) }
        guard let code = q("code") else { return nil }
        guard q("state") == state else { return .failure(.wrongState) }
        return .success(code)
    }

    enum RedirectError: Error, Equatable { case refused(String), wrongState }

    /// Form body for the token endpoint.
    static func form(_ fields: [(String, String)]) -> Data {
        var allowed = CharacterSet.alphanumerics; allowed.insert(charactersIn: "-._~")
        return Data(fields.map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }.joined(separator: "&").utf8)
    }

    struct Token: Equatable { var access: String; var refresh: String?; var expires: Date }

    static func token(_ d: Data, now: Date) -> Token? {
        guard let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let a = j["access_token"] as? String else { return nil }
        let secs = (j["expires_in"] as? Double) ?? (j["expires_in"] as? Int).map(Double.init) ?? 3600
        return Token(access: a, refresh: j["refresh_token"] as? String, expires: now.addingTimeInterval(secs - 60))
    }

    /// Open tasks of a list response, in Google's order. Tasks with an empty title are skipped.
    static func tasks(_ d: Data) -> [TasksSync.Remote]? {
        guard let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        let items = j["items"] as? [[String: Any]] ?? []
        return items.compactMap { t in
            guard let id = t["id"] as? String, (t["status"] as? String) != "completed",
                  let title = (t["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
            return TasksSync.Remote(id: id, title: title)
        }
    }

    /// The id of a task Google just created.
    static func createdID(_ d: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: d) as? [String: Any])?["id"] as? String
    }
}

/// Two-way sync between the To-do list and one Google Tasks list. Titles and done-ness travel; dates don't.
enum TasksSync {
    struct Remote: Equatable { var id: String; var title: String }
    struct Local: Equatable { var id: String; var text: String; var done: Bool; var gid: String? }

    struct Plan: Equatable {
        /// Local items finished or deleted in Google.
        var removeLocal: [String] = []
        /// Local items renamed in Google: (local id, new title).
        var renameLocal: [Rename] = []
        /// Google tasks the list doesn't have yet, in Google's order.
        var addLocal: [Remote] = []
        /// Local items Google doesn't have yet (local ids).
        var createRemote: [String] = []
        var isEmpty: Bool { removeLocal.isEmpty && renameLocal.isEmpty && addLocal.isEmpty && createRemote.isEmpty }
    }
    struct Rename: Equatable { var id: String; var title: String }

    /// `completing`: tasks ticked off here whose "done" hasn't reached Google yet; they aren't added back.
    static func plan(local: [Local], remote: [Remote], completing: Set<String> = []) -> Plan {
        var p = Plan()
        let byID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let known = Set(local.compactMap(\.gid))
        for l in local where !l.done {
            if let g = l.gid {
                if let r = byID[g] {
                    if r.title != l.text { p.renameLocal.append(Rename(id: l.id, title: r.title)) }
                } else {
                    p.removeLocal.append(l.id)
                }
            } else {
                p.createRemote.append(l.id)
            }
        }
        p.addLocal = remote.filter { !known.contains($0.id) && !completing.contains($0.id) }
        return p
    }
}
