import Foundation

func testClaudeStages() {
    check(ClaudeFasi.isTest("npm test"), "npm test is a test")
    check(!ClaudeFasi.isTest("git status"), "git status isn't")
    equal(ClaudeFasi.fase(kind: "READ", label: "a.swift"), 0)
    equal(ClaudeFasi.fase(kind: "EDIT", label: "a.swift"), 1)
    equal(ClaudeFasi.fase(kind: "RUN", label: "swift test"), 2)
    equal(ClaudeFasi.fase(kind: "RUN", label: "ls"), nil)
    let steps: [(kind: String, label: String)] = [("READ", "a"), ("EDIT", "a"), ("RUN", "ls"), ("READ", "b")]
    equal(ClaudeFasi.raggiunta(steps, finita: false), 1, "the furthest stage, even if it went back to reading")
    equal(ClaudeFasi.raggiunta([], finita: false), 0)
    equal(ClaudeFasi.raggiunta(steps, finita: true), 3)

    equal(ClaudeFasi.tempo(4), "0:04"); equal(ClaudeFasi.tempo(725), "12:05"); equal(ClaudeFasi.tempo(3723), "1:02:03")
    equal(ClaudeFasi.tempo(-3), "0:00")

    equal(ClaudeFasi.righe(["--- a/x", "+++ b/x", " ctx", "- const total = 0", "+ const total = sum(items)", " end"]),
          ["- const total = 0", "+ const total = sum(items)"], "last changed lines, no headers")

    equal(ClaudeFasi.verde(finitaDa: nil), 0); equal(ClaudeFasi.verde(finitaDa: 2), 1)
    equal(ClaudeFasi.verde(finitaDa: 17), 0.5); equal(ClaudeFasi.verde(finitaDa: 60), 0)
}
