// Fase 5, compito 3b: gli aggiornamenti automatici con Sparkle (Vendor/Sparkle/LEGGIMI.md), solo nella build di vendita.
// La build personale non collega Sparkle e non lo importa: tutto il file sta dentro #if !PERSONALE.
// Indirizzo dell'appcast (SUFeedURL) e chiave pubblica EdDSA (SUPublicEDKey) stanno nell'Info.plist, scritti da build-vendita.sh.
// In rete Sparkle legge soltanto l'appcast e, se c'è una versione nuova e la si accetta, scarica il suo zip.
// L'interruttore "Cerca aggiornamenti da solo" (pagina Generale, chiave aggiornamentiAutomatici) decide il controllo
// automatico; "Check for Updates…" nel menu cerca subito anche a interruttore spento.
import AppKit
import Sparkle

final class Aggiornamenti: NSObject, SPUUpdaterDelegate {
    static let shared = Aggiornamenti()
    private var controller: SPUStandardUpdaterController?
    private var timer: Timer?
    /// Builds from .github/workflows/build.yml set SUAutomaticallyUpdate: every push to the fork reaches the app on its own.
    private var installaDaSolo: Bool { Bundle.main.object(forInfoDictionaryKey: "SUAutomaticallyUpdate") as? Bool == true }
    /// L'aggiornatore è partito: senza indirizzo o chiave validi resta spento e la voce "Check for Updates…" non compare.
    private(set) var attivo = false

    /// All'avvio della vendita. Non mostra mai un avviso se la configurazione manca: lo scrive solo nel registro.
    func avvia() {
        guard controller == nil else { return }
        let c = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        controller = c
        // la nostra chiave vince su quella che Sparkle tiene da sé (SUEnableAutomaticChecks nelle preferenze dell'app)
        c.updater.automaticallyChecksForUpdates = Impostazioni.aggiornamentiAutomatici
        do {
            try c.updater.start()
            attivo = true
            if installaDaSolo {
                c.updater.automaticallyDownloadsUpdates = true
                // Sparkle won't schedule checks more often than hourly; a light look at the appcast every 5 minutes
                // means a change pushed to the fork shows up a few minutes after its build finishes.
                timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
                    let u = c.updater
                    if u.automaticallyChecksForUpdates && u.canCheckForUpdates { u.checkForUpdatesInBackground() }
                }
            }
        } catch {
            NSLog("Pulsar: aggiornamenti spenti, configurazione di Sparkle non valida: \(error.localizedDescription)")
        }
    }

    /// Downloaded in the background: install and relaunch right away instead of waiting for Pulsar to quit,
    /// which for a menu bar app could be days.
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        guard installaDaSolo else { return false }
        immediateInstallHandler()
        return true
    }

    /// "Check for Updates…": cerca subito e mostra il risultato (anche "sei aggiornato").
    func cercaOra() {
        guard attivo, let c = controller else { return }
        c.checkForUpdates(nil)
    }

    /// L'interruttore della pagina Generale.
    var automatici: Bool {
        get { Impostazioni.aggiornamentiAutomatici }
        set {
            Impostazioni.set(newValue, .aggiornamentiAutomatici)
            controller?.updater.automaticallyChecksForUpdates = newValue
        }
    }
}
