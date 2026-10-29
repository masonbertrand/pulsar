import Foundation

func testTiles2Logic() {
    let bt = """
    Bluetooth Controller:
          State: On
          Connected:
              AirPods Pro:
                  Address: 00:11:22:33:44:55
                  Left Battery Level: 80%
                  Right Battery Level: 75%
                  Case Battery Level: 40%
              Magic Mouse:
                  Battery Level: 55%
          Not Connected:
              Old Speaker:
                  Battery Level: 10%
    """
    let v = BatterieBT.leggi(bt)
    equal(v.map(\.nome), ["AirPods Pro", "Magic Mouse"], "connected devices with a battery")
    equal(v.first?.livelli["Left"], 80); equal(v.first?.livelli["Case"], 40); equal(v.last?.livelli[""], 55)

    let y = Data(#"{"chart":{"result":[{"meta":{"symbol":"AAPL","regularMarketPrice":110,"chartPreviousClose":100}}]}}"#.utf8)
    equal(Quote.leggi(y), Quote.Prezzo(simbolo: "AAPL", prezzo: 110, variazione: 10))
    equal(Quote.leggi(Data("{}".utf8)), nil)
    equal(Quote.testo(64321.7), "64322"); equal(Quote.testo(12.345), "12.35"); equal(Quote.testo(0.12345), "0.1235")

    equal(Abitudini.serie(["2026-10-27", "2026-10-26", "2026-10-24"], oggi: at(9)), 2, "today and yesterday")
    equal(Abitudini.serie(["2026-10-26", "2026-10-25"], oggi: at(9)), 2, "today not done yet still counts yesterday's streak")
    equal(Abitudini.serie([], oggi: at(9)), 0)

    equal(ContoAllaRovescia.giorni(a: at(0, day: 31), da: at(15)), 4)
    equal(ContoAllaRovescia.giorni(a: at(0, day: 25), da: at(15)), -2)

    equal(VPN.leggi("""
    Available network connection services in the current set (*=enabled):
    * (Connected)      1A2B VPN (com.apple.preferences.networkextension.x) "Work VPN"  [VPN:com.x]
    * (Disconnected)   3C4D IPSec "Home"  [IPSec]
    """), [VPN.Voce(nome: "Work VPN", connessa: true), VPN.Voce(nome: "Home", connessa: false)])

    equal(StatisticheFocus.settimana(["2026-10-27": 50, "2026-10-25": 25], oggi: at(9), n: 3), [25, 0, 50])
}
