import Foundation

func testUpdateTiming() {
    let now = at(14)
    check(UpdateTiming.canRestart(claudeWaiting: false, islandOpen: false, meeting: nil, now: now), "free")
    check(!UpdateTiming.canRestart(claudeWaiting: true, islandOpen: false, meeting: nil, now: now), "Claude waiting")
    check(!UpdateTiming.canRestart(claudeWaiting: false, islandOpen: true, meeting: nil, now: now), "island open")
    check(!UpdateTiming.canRestart(claudeWaiting: false, islandOpen: false, meeting: (at(14, 8), at(15)), now: now), "meeting in 8 min")
    check(UpdateTiming.canRestart(claudeWaiting: false, islandOpen: false, meeting: (at(14, 30), at(15)), now: now), "meeting in 30 min")
    check(!UpdateTiming.canRestart(claudeWaiting: false, islandOpen: false, meeting: (at(13, 30), at(14, 30)), now: now), "in a meeting")
    check(UpdateTiming.canRestart(claudeWaiting: false, islandOpen: false, meeting: (at(13), at(14)), now: now), "meeting just ended")

    equal(UpdateTiming.note("<pre>Event tile: show the next event &amp; more\n\nDetails</pre>"), "Event tile: show the next event & more")
    equal(UpdateTiming.note(nil), "")
    equal(UpdateTiming.note(String(repeating: "a", count: 80), max: 10), "aaaaaaaaa…")
}
