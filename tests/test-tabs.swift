import Foundation

func testTabsLogic() {
    equal(CommsLogic.conteggio("3"), 3); equal(CommsLogic.conteggio("99+"), 99); equal(CommsLogic.conteggio("•"), 1)
    equal(CommsLogic.conteggio(""), nil); equal(CommsLogic.conteggio(nil), nil)
    equal(CommsLogic.ordina([(nome: "Mail", badge: "2"), (nome: "Slack", badge: "12"), (nome: "Lark", badge: nil), (nome: "Discord", badge: "2")]).map(\.nome),
          ["Slack", "Discord", "Mail"], "most unread first, ties by name, no badge left out")

    typealias V = AgendaLogic.Voce
    let ev = [V(start: at(9), end: at(10), allDay: false), V(start: at(15), end: at(16), allDay: false),
              V(start: at(0), end: at(0, day: 28), allDay: true), V(start: at(11), end: at(12), allDay: false),
              V(start: at(9, day: 28), end: at(10, day: 28), allDay: false)]
    equal(AgendaLogic.resto(ev, ora: at(10, 30)), [2, 3, 1], "all-day first, past and tomorrow left out")

    equal(NotionLinks.app("https://www.notion.so/team/Roadmap-0123456789abcdef0123456789abcdef")?.absoluteString,
          "notion://www.notion.so/team/Roadmap-0123456789abcdef0123456789abcdef")
    equal(NotionLinks.app("https://example.com/x"), nil, "not Notion")
    equal(NotionLinks.nome("https://www.notion.so/team/Q4-Roadmap-0123456789abcdef0123456789abcdef"), "Q4 Roadmap")
}

func testTabOrder() {
    let tutte = ["casa", "claude", "tessere", "notion"]
    equal(OrdineSchede.leggi(nil, tutte: tutte), tutte, "nothing saved: the default order")
    equal(OrdineSchede.leggi("notion,casa,old,casa", tutte: tutte), ["notion", "casa", "claude", "tessere"], "unknown and repeated dropped, new ones appended")
    equal(OrdineSchede.sposta(tutte, "notion", a: 0), ["notion", "casa", "claude", "tessere"])
    equal(OrdineSchede.sposta(tutte, "casa", a: 99), ["claude", "tessere", "notion", "casa"], "clamped to the end")
    equal(OrdineSchede.sposta(tutte, "missing", a: 0), tutte)
}

func testNotionTasks() {
    equal(NotionTasks.idDatabase("https://www.notion.so/team/0123456789abcdef0123456789abcdef?v=fedcba9876543210fedcba9876543210"),
          "0123456789abcdef0123456789abcdef", "the database id, not the view's")
    equal(NotionTasks.idDatabase("01234567-89ab-cdef-0123-456789abcdef"), "0123456789abcdef0123456789abcdef")
    equal(NotionTasks.idDatabase("not a link"), nil)

    let conCasella = Data(#"{"properties":{"Name":{"type":"title"},"Done":{"type":"checkbox"},"Due":{"type":"date"}}}"#.utf8)
    equal(NotionTasks.schema(conCasella), NotionTasks.Schema(titolo: "Name", fatto: .casella("Done")))
    let conStato = Data(#"{"properties":{"Task":{"type":"title"},"Status":{"type":"status","status":{"options":[{"name":"Not started"},{"name":"In progress"},{"name":"Done"}]}}}}"#.utf8)
    equal(NotionTasks.schema(conStato), NotionTasks.Schema(titolo: "Task", fatto: .stato("Status", opzione: "Done")))

    let q = Data(#"{"results":[{"id":"p1","url":"https://notion.so/p1","properties":{"Name":{"type":"title","title":[{"plain_text":"Buy "},{"plain_text":"milk"}]},"Done":{"type":"checkbox","checkbox":true},"Due":{"type":"date","date":{"start":"2026-10-30"}}}},{"id":"p2","properties":{"Name":{"type":"title","title":[]},"Done":{"type":"checkbox","checkbox":false}}}]}"#.utf8)
    let c = NotionTasks.compiti(q, schema: NotionTasks.Schema(titolo: "Name", fatto: .casella("Done")))
    equal(c.map(\.titolo), ["Buy milk", "Untitled"]); equal(c.map(\.fatto), [true, false]); equal(c.first?.scadenza, "2026-10-30")
}
