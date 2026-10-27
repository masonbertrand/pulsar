import Foundation

func testGoogleTasks() {
    typealias L = TasksSync.Local, R = TasksSync.Remote
    // PKCE: the RFC 7636 example
    equal(GoogleTasksAPI.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "PKCE S256")
    let v = GoogleTasksAPI.verifier()
    check(v.count >= 43 && v.count <= 128, "verifier length")

    let u = GoogleTasksAPI.signInURL(clientID: "abc.apps.googleusercontent.com", redirect: "http://127.0.0.1:5000", verifier: v, state: "s1")
    let q = URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems ?? []
    equal(q.first { $0.name == "scope" }?.value, "https://www.googleapis.com/auth/tasks")
    equal(q.first { $0.name == "access_type" }?.value, "offline", "asks for a refresh token")

    equal(GoogleTasksAPI.redirect(requestLine: "GET /?state=s1&code=4/xyz&scope=x HTTP/1.1", state: "s1"), .success("4/xyz"))
    equal(GoogleTasksAPI.redirect(requestLine: "GET /?state=other&code=4/xyz HTTP/1.1", state: "s1"), .failure(.wrongState))
    equal(GoogleTasksAPI.redirect(requestLine: "GET /?error=access_denied&state=s1 HTTP/1.1", state: "s1"), .failure(.refused("access_denied")))
    equal(GoogleTasksAPI.redirect(requestLine: "GET /favicon.ico HTTP/1.1", state: "s1"), nil, "not the redirect")

    equal(String(decoding: GoogleTasksAPI.form([("a", "1 2"), ("b", "x/y")]), as: UTF8.self), "a=1%202&b=x%2Fy")
    let tok = GoogleTasksAPI.token(Data(#"{"access_token":"A","expires_in":3599,"refresh_token":"R"}"#.utf8), now: at(10))
    equal(tok?.refresh, "R"); equal(tok?.expires, at(10).addingTimeInterval(3539))
    equal(GoogleTasksAPI.token(Data(#"{"error":"invalid_grant"}"#.utf8), now: at(10)), nil)

    let list = Data(#"{"items":[{"id":"1","title":"Buy milk","status":"needsAction"},{"id":"2","title":"Old","status":"completed"},{"id":"3","title":"  ","status":"needsAction"}]}"#.utf8)
    equal(GoogleTasksAPI.tasks(list), [R(id: "1", title: "Buy milk")], "open tasks with a title")
    equal(GoogleTasksAPI.tasks(Data("{}".utf8)), [], "empty list has no items key")

    // sync
    let p = TasksSync.plan(local: [
        L(id: "a", text: "Buy milk", done: false, gid: "1"),          // same
        L(id: "b", text: "Call mum", done: false, gid: "2"),          // finished in Google
        L(id: "c", text: "Typo", done: false, gid: "3"),              // renamed in Google
        L(id: "d", text: "New here", done: false, gid: nil),          // not in Google yet
        L(id: "e", text: "Just ticked", done: true, gid: "5"),        // ticked here, leaving
    ], remote: [R(id: "1", title: "Buy milk"), R(id: "3", title: "Fixed"), R(id: "4", title: "From phone"), R(id: "6", title: "Ticked offline")],
       completing: ["6"])
    equal(p.removeLocal, ["b"])
    equal(p.renameLocal, [TasksSync.Rename(id: "c", title: "Fixed")])
    equal(p.addLocal, [R(id: "4", title: "From phone")], "new in Google, and not one we're completing")
    equal(p.createRemote, ["d"])
    check(TasksSync.plan(local: [L(id: "a", text: "x", done: false, gid: "1")], remote: [R(id: "1", title: "x")]).isEmpty, "in sync")
}
