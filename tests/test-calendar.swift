import Foundation

func testNextEvent() {
    typealias V = ProssimoEvento.Voce
    let now = at(18)
    equal(ProssimoEvento.scegli([], ora: now), nil, "nothing")
    let today = V(start: at(19), end: at(20), allDay: false)
    let tomorrowAllDay = V(start: at(0, day: 28), end: at(0, day: 29), allDay: true)
    let tomorrowNine = V(start: at(9, day: 28), end: at(10, day: 28), allDay: false)
    let past = V(start: at(9), end: at(10), allDay: false)
    equal(ProssimoEvento.scegli([tomorrowNine, today, past], ora: now), 1, "today's next event wins")
    equal(ProssimoEvento.scegli([past, tomorrowAllDay, tomorrowNine], ora: now), 2, "empty evening: tomorrow, timed before all-day")
    equal(ProssimoEvento.scegli([tomorrowAllDay], ora: now), 0, "all-day when that's all there is")
    let ongoing = V(start: at(17), end: at(19), allDay: false)
    equal(ProssimoEvento.scegli([tomorrowNine, ongoing], ora: now), 1, "an event under way counts for today")
    let multiDay = V(start: at(0, day: 26), end: at(0, day: 29), allDay: true)
    equal(ProssimoEvento.scegli([tomorrowNine, multiDay], ora: now), 1, "a trip that started yesterday is today")

    equal(ProssimoEvento.giorno(at(19), ora: now, inglese: true), nil, "today has no label")
    equal(ProssimoEvento.giorno(at(9, day: 28), ora: now, inglese: true), "Tomorrow")
    equal(ProssimoEvento.giorno(at(9, day: 29), ora: now, inglese: true), "Thursday")
    equal(ProssimoEvento.giorno(at(9, day: 29), ora: now, inglese: false), "Giovedì")
}
