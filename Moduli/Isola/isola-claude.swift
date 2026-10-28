// 28/10: Claude Code as a tab of the island, so you don't have to go to the terminal: your sessions on the left,
// the chosen one on the right with what it's doing, Allow/Deny when it asks, its questions, the files it changed,
// and a box to send it a message (delivered by the hook after Claude's next step, or when it stops, waking it up).
// The data and the actions are the Agent's (agente.swift); this is only another view of them.
import SwiftUI
import AppKit

struct ClaudeTab: View {
    @ObservedObject var store: AgentStore
    @ObservedObject var model: IslandModel
    @State private var messaggio = ""

    static let altezza: CGFloat = 210

    var body: some View {
        if store.sessions.isEmpty {
            VCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(T("Nessuna sessione di Claude Code", "No Claude Code sessions yet")).font(.system(size: 15, weight: .medium)).foregroundStyle(Volta.t1)
                    Text(T("Avvia claude in un terminale: qui vedrai cosa fa, i permessi e le domande, e potrai scrivergli.",
                           "Start claude in a terminal: you'll see what it does here, answer its permissions and questions, and message it."))
                        .font(.system(size: 12)).foregroundStyle(Volta.t2).fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            HStack(spacing: 8) {
                lista.frame(width: 200)
                if let s = store.current { dettaglio(s) }
            }
        }
    }

    // MARK: sessions

    private var sessioni: [AgentSession] { Array(store.sessions.sorted { $0.updated > $1.updated }.prefix(8)) }

    private var lista: some View {
        VCard(padding: 8) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(sessioni) { s in
                        Button { store.selectedID = s.id } label: {
                            HStack(spacing: 8) {
                                Circle().fill(colore(s)).frame(width: 7, height: 7)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(s.name).font(.system(size: 12.5)).foregroundStyle(Volta.t1).lineLimit(1)
                                    Text(s.statoInParole).font(.system(size: 10.5)).foregroundStyle(Volta.t3).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(s.id == store.current?.id ? Volta.pill : .clear))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func colore(_ s: AgentSession) -> Color {
        if s.pending != nil || s.question != nil { return Night.amber }
        if s.viva { return Volta.a2 }
        if s.status == "done" { return Color.green.opacity(0.75) }
        return Volta.t3
    }

    // MARK: the chosen session

    @ViewBuilder
    private func dettaglio(_ s: AgentSession) -> some View {
        if let q = s.question {
            AgentQuestionCard(question: q, project: s.name, send: { store.answerQuestion(q, answers: $0) }, toTerminal: { store.questionToTerminal(q) })
        } else {
            VCard(glow: s.pending != nil ? Volta.a1 : Volta.a2, breathe: s.pending != nil, padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Volta.t1).lineLimit(1)
                            Text(s.statoInParole).font(.system(size: 11.5)).foregroundStyle(Volta.t3).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        HStack(spacing: 6) {
                            ForEach(s.changeList.prefix(2), id: \.path) { c in
                                ChangeRow(path: c.path, change: c.change) { DiffWindow.open(store: store, session: s, path: c.path) }
                            }
                        }
                    }
                    if let p = s.pending {
                        Text(T("Claude vuole \(p.tool == "Bash" ? "lanciare un comando" : "usare \(p.tool)")",
                               "Claude wants to \(p.tool == "Bash" ? "run a command" : "use \(p.tool)")"))
                            .font(.system(size: 12)).foregroundStyle(Volta.t2)
                        Text(p.what).font(.system(size: 12, design: .monospaced)).foregroundStyle(Volta.t1).lineLimit(2)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Volta.card2))
                        HStack(spacing: 7) {
                            VPill(title: T("Nega", "Deny"), key: "N") { store.selectedID = s.id; store.answer(false) }
                            if p.always == true { VPill(title: T("Sempre", "Always"), key: "A") { store.selectedID = s.id; store.answerAlways() } }
                            VPill(title: T("Consenti", "Allow"), key: "Y", kind: .primary) { store.selectedID = s.id; store.answer(true) }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(s.steps.suffix(3).enumerated()), id: \.offset) { _, st in
                                HStack(spacing: 8) {
                                    Text(st.state == "now" ? "›" : st.state == "failed" ? "×" : "✓").frame(width: 12)
                                    Text(StepKind.phrase(st.state == "now" ? StepKind.of(st.kind).doing : StepKind.of(st.kind).done, st)).lineLimit(1)
                                }
                                .font(.system(size: 12)).foregroundStyle(st.state == "now" ? Volta.t1 : Volta.t3)
                            }
                            if s.steps.isEmpty, let r = s.richiesta {
                                Text(r).font(.system(size: 12)).foregroundStyle(Volta.t2).lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                        scrivi(s)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    /// The message box. While something is typed the island stays open (IslandModel.trattiene).
    private func scrivi(_ s: AgentSession) -> some View {
        HStack(spacing: 6) {
            TextField(T("Scrivi a Claude…", "Message Claude…"), text: $messaggio)
                .textFieldStyle(.plain).font(.system(size: 12.5)).foregroundStyle(Volta.t1)
                .padding(.horizontal, 12).frame(height: 30)
                .background(Capsule().fill(Volta.card2))
                .onSubmit { invia(s) }
            Button { invia(s) } label: {
                Image(systemName: "arrow.up").font(.system(size: 12, weight: .semibold)).foregroundStyle(Volta.primT)
                    .frame(width: 30, height: 30).background(Circle().fill(messaggio.isEmpty ? Volta.pill : Volta.prim))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(messaggio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .hint(T("Invia a Claude", "Send to Claude"))
        }
        .onChange(of: messaggio) { _, v in model.trattiene = !v.isEmpty }
    }

    private func invia(_ s: AgentSession) {
        let t = messaggio.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        store.send(t, to: s.id)
        messaggio = ""
        model.trattiene = false
    }
}
