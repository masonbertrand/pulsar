// 28/10: Claude Code as a tab of the island, so you don't have to go to the terminal. Laid out like the user's
// reference ("Claude glows while it works … then it turns green, and slowly fades away"):
// left the project, a big timer and the stage in words; right what's happening now (the file being edited with its
// last changed lines, a permission to answer, or Claude's summary when it's done) and a box to message it;
// at the bottom the four stages, Read, Edit, Test, Done. The whole island glows copper while Claude works and green
// when it's done (ClaudeGlow, drawn behind the panel by isola.swift).
// The data and the actions are the Agent's (agente.swift); the reading of a session is in claude-logica.swift.
import SwiftUI
import AppKit

struct ClaudeTab: View {
    @ObservedObject var store: AgentStore
    @ObservedObject var model: IslandModel
    @State private var messaggio = ""

    static let altezza: CGFloat = 170
    static let rame = Color(red: 0.85, green: 0.47, blue: 0.27)      // Claude's orange

    var body: some View {
        if let s = store.current {
            if let q = s.question {
                AgentQuestionCard(question: q, project: s.name, send: { store.answerQuestion(q, answers: $0) }, toTerminal: { store.questionToTerminal(q) })
            } else {
                sessione(s)
            }
        } else {
            VStack(spacing: 6) {
                Text(T("Nessuna sessione di Claude Code", "No Claude Code sessions yet")).font(.system(size: 17, weight: .semibold)).foregroundStyle(Volta.t1)
                Text(T("Avvia claude in un terminale: qui vedrai cosa fa e potrai rispondergli.",
                       "Start claude in a terminal: you'll follow it here and answer it from here."))
                    .font(.system(size: 12.5)).foregroundStyle(Volta.t2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func sessione(_ s: AgentSession) -> some View {
        let finita = s.status == "done" && s.pending == nil
        let passi = s.steps.map { (kind: $0.kind, label: $0.label) }
        let fase = ClaudeFasi.raggiunta(passi, finita: finita)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                sinistra(s, fase: fase, finita: finita)
                Spacer(minLength: 0)
                destra(s, finita: finita).frame(width: 340)
            }
            Spacer(minLength: 8)
            fasi(fase, finita: finita, lavora: s.viva && !finita)
        }
    }

    // MARK: left: project, timer, stage

    private func sinistra(_ s: AgentSession, fase: Int, finita: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "asterisk").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 22, height: 22).background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Self.rame))
                Text(s.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Volta.t1).lineLimit(1)
                if store.sessions.count > 1 { altre }
            }
            .padding(.bottom, 4)
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let fine = finita && s.finished > 0 ? s.finished : ctx.date.timeIntervalSince1970
                Text(ClaudeFasi.tempo(fine - s.started)).font(.system(size: 42, weight: .bold).monospacedDigit())
                    .foregroundStyle(Volta.t1).lineLimit(1).minimumScaleFactor(0.6)
            }
            Text(riga(s, fase: fase, finita: finita)).font(.system(size: 13)).foregroundStyle(Volta.t2).lineLimit(1)
        }
    }

    private func riga(_ s: AgentSession, fase: Int, finita: Bool) -> String {
        if finita { return T("Fatto · ogni passo", "Done · every step") }
        if s.pending != nil { return T("Aspetta il tuo ok", "Waiting for your OK") }
        let cosa = [T("Legge", "Reading"), T("Fa modifiche", "Making changes"), T("Prova", "Testing")][min(fase, 2)]
        return T("\(cosa) · passo \(fase + 1) di 4", "\(cosa) · step \(fase + 1) of 4")
    }

    /// The other sessions, to switch to.
    private var altre: some View {
        Menu {
            ForEach(store.sessions.sorted { $0.updated > $1.updated }.prefix(8)) { x in
                Button("\(x.name) · \(x.statoInParole)") { store.selectedID = x.id }
            }
        } label: {
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Volta.t2)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .hint(T("Altre sessioni", "Other sessions"))
    }

    // MARK: right: what's happening now, and the message box

    @ViewBuilder
    private func destra(_ s: AgentSession, finita: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let p = s.pending {
                riquadro {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(T("Claude vuole \(p.tool == "Bash" ? "lanciare un comando" : "usare \(p.tool)")",
                               "Claude wants to \(p.tool == "Bash" ? "run a command" : "use \(p.tool)")"))
                            .font(.system(size: 12.5, weight: .medium)).foregroundStyle(Volta.t1)
                        Text(p.what).font(.system(size: 12, design: .monospaced)).foregroundStyle(Volta.t1).lineLimit(2)
                        HStack(spacing: 7) {
                            VPill(title: T("Nega", "Deny"), key: "N") { store.selectedID = s.id; store.answer(false) }
                            if p.always == true { VPill(title: T("Sempre", "Always"), key: "A") { store.selectedID = s.id; store.answerAlways() } }
                            VPill(title: T("Consenti", "Allow"), key: "Y", kind: .primary) { store.selectedID = s.id; store.answer(true) }
                        }
                    }
                }
            } else if finita {
                riquadro {
                    Text(s.summary.isEmpty ? T("Fatto.", "Done.") : s.summary).font(.system(size: 13)).foregroundStyle(Volta.t1)
                        .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
                scrivi(s, segnaposto: T("Rispondi a Claude…", "Reply to Claude…"))
            } else {
                if let f = fileInCorso(s) { diff(s, path: f) }
                scrivi(s, segnaposto: T("Scrivi a Claude…", "Message Claude…"))
            }
        }
    }

    private func riquadro<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Volta.body.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Volta.t1.opacity(0.12), lineWidth: 1))
    }

    /// The file Claude is editing (or edited last): the one named by the latest edit step, else the most changed.
    private func fileInCorso(_ s: AgentSession) -> String? {
        let paths = s.changeList.map(\.path)
        if let e = s.steps.last(where: { $0.kind == "EDIT" }), let p = paths.first(where: { ($0 as NSString).lastPathComponent == e.label || $0.hasSuffix(e.label) }) {
            return p
        }
        return paths.first
    }

    private func diff(_ s: AgentSession, path: String) -> some View {
        let nome = (path as NSString).lastPathComponent
        let ext = (nome as NSString).pathExtension.uppercased()
        let righe = ClaudeFasi.righe(store.diffLines(session: s, path: path))
        let ora = s.steps.last?.kind == "EDIT" && s.steps.last?.state == "now"
        return Button { DiffWindow.open(store: store, session: s, path: path) } label: {
            riquadro {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        if !ext.isEmpty {
                            Text(String(ext.prefix(4))).font(.system(size: 9.5, weight: .bold)).foregroundStyle(Volta.t1)
                                .padding(.horizontal, 5).frame(height: 18).background(RoundedRectangle(cornerRadius: 5).fill(Volta.pill))
                        }
                        Text(nome).font(.system(size: 13, weight: .medium)).foregroundStyle(Volta.t1).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(ora ? T("in modifica", "being edited") : T("modificato", "edited")).font(.system(size: 12)).foregroundStyle(Volta.t2)
                    }
                    ForEach(Array(righe.enumerated()), id: \.offset) { _, r in
                        let aggiunta = r.hasPrefix("+")
                        Text(r).font(.system(size: 11.5, design: .monospaced)).lineLimit(1)
                            .foregroundStyle(aggiunta ? Color(red: 0.55, green: 0.85, blue: 0.55) : Color(red: 0.95, green: 0.5, blue: 0.5))
                            .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 5).fill(aggiunta ? Color.green.opacity(0.16) : Color.red.opacity(0.16)))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .hint(T("Vedi tutte le modifiche", "See all the changes"))
    }

    /// The message box. While something is typed the island stays open (IslandModel.trattiene).
    private func scrivi(_ s: AgentSession, segnaposto: String) -> some View {
        HStack(spacing: 6) {
            TextField(segnaposto, text: $messaggio)
                .textFieldStyle(.plain).font(.system(size: 12.5)).foregroundStyle(Volta.t1)
                .padding(.horizontal, 12).frame(height: 30)
                .background(Capsule().fill(Volta.body.opacity(0.55)))
                .onSubmit { invia(s) }
            Button { invia(s) } label: {
                Image(systemName: "arrow.up").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 30, height: 30).background(Circle().fill(messaggio.isEmpty ? Volta.pill : Self.rame))
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

    // MARK: the four stages

    private func fasi(_ fase: Int, finita: Bool, lavora: Bool) -> some View {
        let nomi = [T("Legge", "Read"), T("Modifica", "Edit"), T("Prova", "Test"), T("Fatto", "Done")]
        return HStack(spacing: 10) {
            ForEach(0..<ClaudeFasi.quante, id: \.self) { i in
                VStack(alignment: .leading, spacing: 6) {
                    SegmentoFase(pieno: finita || i < fase, attivo: !finita && lavora && i == fase)
                    Text(nomi[i]).font(.system(size: 12, weight: i == fase || finita ? .medium : .regular))
                        .foregroundStyle(i <= fase || finita ? Volta.t1 : Volta.t3)
                }
            }
        }
    }
}

/// One stage of the bar: full when passed, a light moving across it while it's the current one.
private struct SegmentoFase: View {
    let pieno: Bool
    let attivo: Bool
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Volta.t1.opacity(0.18))
                if pieno { Capsule().fill(Volta.t1) }
                if attivo {
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: Leggera.on)) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
                        Capsule().fill(Volta.t1).frame(width: g.size.width * 0.4)
                            .offset(x: (g.size.width * 1.4) * t - g.size.width * 0.4)
                    }
                    .clipShape(Capsule())
                }
            }
        }
        .frame(height: 4)
    }
}

/// Behind the whole island on the Claude tab: dark at the top, copper at the bottom while Claude works,
/// green when it has finished, fading back over half a minute.
struct ClaudeGlow: View {
    @ObservedObject var store: AgentStore
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let s = store.current
            let finita = s.map { $0.status == "done" && $0.pending == nil } ?? false
            let verde = finita ? ClaudeFasi.verde(finitaDa: s.map { ctx.date.timeIntervalSince1970 - $0.finished }) : 0
            let rame = (s?.viva ?? false) && !finita ? 1.0 : 0.0
            ZStack {
                LinearGradient(colors: [.clear, ClaudeTab.rame.opacity(Theme.light ? 0.35 : 0.75)], startPoint: .top, endPoint: .bottom)
                    .opacity(rame)
                LinearGradient(colors: [.clear, Color(red: 0.12, green: 0.55, blue: 0.25).opacity(Theme.light ? 0.35 : 0.8)], startPoint: .top, endPoint: .bottom)
                    .opacity(verde)
            }
            .animation(.easeInOut(duration: 1.2), value: rame)
            .animation(.easeInOut(duration: 1.2), value: verde)
        }
        .allowsHitTesting(false)
    }
}
