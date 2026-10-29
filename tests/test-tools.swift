import Foundation

func testToolsLogic() {
    equal(RiordinaDownload.cartella("Photo.HEIC", isCartella: false), "Images")
    equal(RiordinaDownload.cartella("report.pdf", isCartella: false), "Documents")
    equal(RiordinaDownload.cartella("Setup.dmg", isCartella: false), "Installers")
    equal(RiordinaDownload.cartella("file.crdownload", isCartella: false), nil, "downloads still in progress stay")
    equal(RiordinaDownload.cartella("Project", isCartella: true), nil, "folders stay")
    equal(RiordinaDownload.cartella("notes.xyz", isCartella: false), "Other")

    let noti = ["America/New_York", "Europe/London", "Asia/Tokyo", "America/Los_Angeles"]
    equal(FusoOrario.cerca("tokyo", tra: noti), "Asia/Tokyo")
    equal(FusoOrario.cerca("New York", tra: noti), "America/New_York")
    equal(FusoOrario.cerca("Europe/London", tra: noti), "Europe/London")
    equal(FusoOrario.cerca("Atlantis", tra: noti), nil)
    equal(FusoOrario.nome("America/Los_Angeles"), "Los Angeles")

    equal(Colore.hex(1, 0.5, 0), "#FF8000"); equal(Colore.hex(-1, 2, 0.2), "#00FF33")

    equal(Invitati.mail(["a@x.com", "not-an-email", "b@y.org"], oggetto: "Standup")?.absoluteString, "mailto:a@x.com,b@y.org?subject=Standup")
    equal(Invitati.mail([], oggetto: "x"), nil)
}
