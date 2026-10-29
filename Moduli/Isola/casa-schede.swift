// 28/10: Home as three colour cards (the user's reference: "Home got a glow-up"): Claude Code, Music, Focus.
// Each card is a gradient from the panel's dark into its own colour, a small title and round button on top,
// a big value and a short line at the bottom. Every card does something when clicked.
// This leaves Pulsar's grey, no-bold style on purpose, for this page only; both themes have their own gradients.
import SwiftUI
import AppKit

/// The gradients, one pair per theme. Kept here so the look can be changed in one place.
enum CasaColori {
    static func claude(_ chiaro: Bool) -> [Color] {
        chiaro ? [Color(red: 0.99, green: 0.95, blue: 0.91), Color(red: 0.93, green: 0.66, blue: 0.47)]
               : [Color(red: 0.07, green: 0.06, blue: 0.06), Color(red: 0.80, green: 0.47, blue: 0.26)]
    }
    static func musica(_ chiaro: Bool) -> [Color] {
        chiaro ? [Color(red: 0.99, green: 0.93, blue: 0.94), Color(red: 0.93, green: 0.45, blue: 0.50)]
               : [Color(red: 0.07, green: 0.03, blue: 0.04), Color(red: 0.88, green: 0.20, blue: 0.27)]
    }
    static func focus(_ chiaro: Bool) -> [Color] {
        chiaro ? [Color(red: 0.96, green: 0.94, blue: 1.00), Color(red: 0.72, green: 0.55, blue: 0.95)]
               : [Color(red: 0.05, green: 0.04, blue: 0.09), Color(red: 0.72, green: 0.48, blue: 0.96)]
    }
    static let viola = Color(red: 0.66, green: 0.40, blue: 0.92)
}

struct CasaSchede: View {
    @ObservedObject var model: IslandModel
    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let st = model.agent { SchedaClaude(store: st, apri: { model.tab = .claude }) } else { SchedaClaude(store: nil, apri: { model.tab = .claude }) }
            }
            .onTapGesture { model.tab = .claude }          // 28/10: Claude has its own tab now
            .hint(T("Apri Claude", "Open Claude"))
            if let m = model.home as? MediaSource { SchedaMusica(media: m) } else { SchedaMusica(media: nil) }
            if let d = model.dial?.store { SchedaFocus(store: d) }
        }
    }
}

/// The shared shape of the three cards.
private struct Scheda<Accessorio: View, Piede: View>: View {
    let titolo: String
    let grande: String
    let sotto: String
    let colori: [Color]
    @ViewBuilder var accessorio: () -> Accessorio
    /// 29/10: a row of controls along the bottom of the card.
    @ViewBuilder var piede: () -> Piede

    var body: some View {
        let chiaro = Theme.light
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(titolo).font(.system(size: 13, weight: .medium)).opacity(0.85)
                Spacer(minLength: 6)
                accessorio()
            }
            Spacer(minLength: 4)
            Text(grande).font(.system(size: 30, weight: .bold)).lineLimit(1).minimumScaleFactor(0.55)
            Text(sotto).font(.system(size: 12.5)).opacity(0.75).lineLimit(1)
            piede().padding(.top, 8)
        }
        .foregroundStyle(chiaro ? Color.black.opacity(0.85) : Color.white)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            let forma = RoundedRectangle(cornerRadius: 22, style: .continuous)
            ZStack {
                forma.fill(LinearGradient(colors: [colori[0], colori[0], colori[1]], startPoint: .top, endPoint: .bottom))
                // the glow rising from the bottom edge, as in the reference
                RadialGradient(colors: [colori[1].opacity(0.95), colori[1].opacity(0.0)], center: UnitPoint(x: 0.5, y: 1.2),
                               startRadius: 0, endRadius: 190)
                    .clipShape(forma)
                forma.strokeBorder(LinearGradient(colors: [Color.white.opacity(chiaro ? 0.5 : 0.06), colori[1].opacity(0.8)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .shadow(color: colori[1].opacity(chiaro ? 0.3 : 0.5), radius: 14, y: 6)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension Scheda where Piede == EmptyView {
    init(titolo: String, grande: String, sotto: String, colori: [Color], @ViewBuilder accessorio: @escaping () -> Accessorio) {
        self.init(titolo: titolo, grande: grande, sotto: sotto, colori: colori, accessorio: accessorio, piede: { EmptyView() })
    }
}

/// 29/10: a small control in a card's bottom row; `forte` is the main one (filled).
private struct Pillola: View {
    let simbolo: String
    var testo: String? = nil
    var forte = false
    let nome: String
    let azione: () -> Void
    var body: some View {
        let chiaro = Theme.light
        Button(action: azione) {
            HStack(spacing: 5) {
                Image(systemName: simbolo).font(.system(size: 11, weight: .semibold))
                if let testo { Text(testo).font(.system(size: 11.5, weight: .medium)).lineLimit(1) }
            }
            .foregroundStyle(forte ? (chiaro ? Color.white : Color.black.opacity(0.85)) : (chiaro ? Color.black.opacity(0.8) : Color.white))
            .padding(.horizontal, testo == nil ? 0 : 10).frame(minWidth: 28).frame(height: 26)
            .background(Capsule().fill(forte ? (chiaro ? Color.black.opacity(0.8) : Color.white) : (chiaro ? Color.black.opacity(0.08) : Color.white.opacity(0.15))))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).hint(nome)
    }
}

/// A round button in a card's corner.
private struct Tondo: View {
    let simbolo: String
    var pieno = false            // white disc with a coloured symbol, like Focus's play
    var colore: Color = .white
    let nome: String
    let azione: () -> Void
    var body: some View {
        Button(action: azione) {
            Image(systemName: simbolo).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(pieno ? colore : (Theme.light ? Color.black.opacity(0.8) : Color.white))
                .frame(width: 40, height: 40)
                .background(Circle().fill(pieno ? Color.white : (Theme.light ? Color.black.opacity(0.08) : Color.white.opacity(0.14))))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hint(nome)
    }
}

// MARK: - Claude Code

private struct SchedaClaude: View {
    var store: AgentStore?
    let apri: () -> Void
    var body: some View {
        if let store { Viva(store: store, apri: apri) }
        else { Self.scheda(oggi: 0, finiti: 0, riga: T("lavori oggi", "jobs today"), store: nil, apri: apri) }
    }

    private struct Viva: View {
        @ObservedObject var store: AgentStore
        let apri: () -> Void
        var body: some View {
            let inizio = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
            let oggi = store.sessions.filter { $0.started >= inizio }
            let finiti = oggi.filter { $0.status == "done" }.count
            let riga: String = {
                if store.hasPending { return T("aspetta il tuo ok", "waiting for your OK") }
                if store.question != nil { return T("ha una domanda", "has a question") }
                if let s = store.active.first, let step = s.steps.last {
                    return StepKind.phrase(step.state == "now" ? StepKind.of(step.kind).doing : StepKind.of(step.kind).done, step)
                }
                return oggi.count == 1 ? T("lavoro oggi", "job today") : T("lavori oggi", "jobs today")
            }()
            SchedaClaude.scheda(oggi: oggi.count, finiti: finiti, riga: riga, store: store, apri: apri)
        }
    }

    static func scheda(oggi: Int, finiti: Int, riga: String, store: AgentStore?, apri: @escaping () -> Void) -> some View {
        let quota = oggi == 0 ? 0 : Double(finiti) / Double(oggi)
        return Scheda(titolo: "Claude Code", grande: "\(oggi)", sotto: riga, colori: CasaColori.claude(Theme.light)) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.18), lineWidth: 4)
                Circle().trim(from: 0, to: quota).stroke(Theme.light ? Color.black.opacity(0.75) : Color.white,
                                                          style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(Int((quota * 100).rounded()))%").font(.system(size: 10.5, weight: .semibold).monospacedDigit())
            }
            .frame(width: 40, height: 40)
            .hint(T("Lavori di oggi finiti", "Today's jobs finished"))
        } piede: {
            HStack(spacing: 6) {
                if let s = store, s.hasPending {
                    // answer Claude's permission right here
                    Pillola(simbolo: "xmark", testo: T("Nega", "Deny"), nome: T("Nega il permesso", "Deny")) { s.answer(false) }
                    Pillola(simbolo: "checkmark", testo: T("Consenti", "Allow"), forte: true, nome: T("Consenti", "Allow")) { s.answer(true) }
                } else if store?.question != nil {
                    Pillola(simbolo: "bubble.left", testo: T("Rispondi", "Answer"), forte: true, nome: T("Rispondi a Claude", "Answer Claude"), azione: apri)
                } else {
                    Pillola(simbolo: "asterisk", testo: T("Apri", "Open"), nome: T("Apri la scheda Claude", "Open the Claude tab"), azione: apri)
                    Pillola(simbolo: "terminal", testo: "Terminal", nome: T("Apri il Terminale", "Open Terminal")) {
                        ApriApp.apri(bundle: "com.apple.Terminal", nome: "Terminal")
                    }
                }
            }
        }
    }
}

// MARK: - Music

private struct SchedaMusica: View {
    var media: MediaSource?
    var body: some View {
        if let media { Viva(media: media) } else { vuota }
    }

    private var vuota: some View {
        Scheda(titolo: T("Musica", "Music"), grande: "Spotify", sotto: T("Apri la tua musica", "Open your music"), colori: CasaColori.musica(Theme.light)) {
            Tondo(simbolo: "music.note", nome: T("Apri Spotify", "Open Spotify")) { Self.apri(nil) }
        }
        .onTapGesture { Self.apri(nil) }
    }

    private struct Viva: View {
        @ObservedObject var media: MediaSource
        var body: some View {
            let t = media.track ?? media.last
            let suona = media.track?.playing == true
            Scheda(titolo: suona ? T("In ascolto", "Now playing") : T("Musica", "Music"),
                   grande: t?.title ?? "Spotify",
                   sotto: t.map { $0.artist.isEmpty ? $0.app : $0.artist } ?? T("Apri la tua musica", "Open your music"),
                   colori: CasaColori.musica(Theme.light)) {
                Tondo(simbolo: "arrow.up.forward.app", nome: T("Apri \(t?.app ?? "Spotify")", "Open \(t?.app ?? "Spotify")")) { SchedaMusica.apri(t?.app) }
            } piede: {
                let live = media.track != nil
                HStack(spacing: 6) {
                    Pillola(simbolo: "backward.fill", nome: T("Precedente", "Previous")) { media.command(.previous) }.disabled(!live)
                    Pillola(simbolo: suona ? "pause.fill" : "play.fill", forte: true, nome: suona ? T("Pausa", "Pause") : T("Riproduci", "Play")) {
                        live ? media.command(.playPause) : media.resumeLast()
                    }
                    Pillola(simbolo: "forward.fill", nome: T("Successivo", "Next")) { media.command(.next) }.disabled(!live)
                    Pillola(simbolo: "shuffle", nome: T("Casuale", "Shuffle")) { media.command(.shuffle) }.disabled(!live)
                }
            }
            .onTapGesture { SchedaMusica.apri(t?.app) }
            .hint(T("Apri \(t?.app ?? "Spotify")", "Open \(t?.app ?? "Spotify")"))
        }
    }

    static func apri(_ app: String?) {
        let id = app == "Music" ? "com.apple.Music" : "com.spotify.client"
        if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.openApplication(at: u, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

// MARK: - Focus (the same timer as the Timer tile and the dial)

private struct SchedaFocus: View {
    @ObservedObject var store: DialStore
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let resto: Double? = store.timerEnd.map { max(0, $0.timeIntervalSince(ctx.date)) }
            let testo = resto.map { String(format: "%d:%02d", Int($0) / 60, Int($0) % 60) } ?? "\(store.timerMinutes):00"
            Scheda(titolo: "Focus", grande: testo,
                   sotto: resto == nil ? T("Pronto a partire", "Ready to start") : T("Concentrato", "Focusing"),
                   colori: CasaColori.focus(Theme.light)) {
                Tondo(simbolo: resto == nil ? "play.fill" : "stop.fill", pieno: true, colore: CasaColori.viola,
                      nome: resto == nil ? T("Avvia \(store.timerMinutes) minuti", "Start \(store.timerMinutes) minutes") : T("Ferma", "Stop")) { avvia() }
            } piede: {
                HStack(spacing: 6) {
                    Pillola(simbolo: "minus", nome: T("5 minuti in meno", "5 minutes less")) { durata(-5) }.disabled(resto != nil)
                    Pillola(simbolo: "plus", nome: T("5 minuti in più", "5 minutes more")) { durata(5) }.disabled(resto != nil)
                    Pillola(simbolo: "calendar.badge.plus", testo: T("Blocca", "Block"),
                            nome: T("Metti \(store.timerMinutes) minuti di focus nel calendario", "Put \(store.timerMinutes) min of focus in your calendar")) {
                        CalendarModel.shared.bloccaFocus(minuti: store.timerMinutes)
                    }
                }
            }
            .onTapGesture { avvia() }
            .hint(resto == nil ? T("Avvia il focus", "Start focusing") : T("Ferma il focus", "Stop focusing"))
        }
    }

    private func durata(_ d: Int) {
        store.timerMinutes = max(5, min(120, store.timerMinutes + d))
        Impostazioni.set(store.timerMinutes, .dialTimer)
    }

    private func avvia() {
        if store.timerEnd == nil { store.timerEnd = Date().addingTimeInterval(Double(store.timerMinutes * 60)); store.now = Date() }
        else { store.timerEnd = nil }
    }
}

/// The date and time in the island's top bar on Home, when Claude has nothing to say: "Wed 28 Oct 2026 01:16".
struct DataOra: View {
    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let lingua = Locale(identifier: pulsarItalian ? "it_IT" : "en_US")
            (Text(ctx.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year().locale(lingua)) + "  ").foregroundStyle(Volta.t2)
             + Text(ctx.date.formatted(date: .omitted, time: .shortened)).fontWeight(.semibold).foregroundStyle(Volta.t1))
                .font(.system(size: 11.5).monospacedDigit()).lineLimit(1)
        }
    }
}
