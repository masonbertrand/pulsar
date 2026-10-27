// Logic that was in Pulsar before the tests existed.
import Foundation

func testMeeting() {
    let zoom = Riunione.link(in: [nil, "Join: https://us02web.zoom.us/j/123456789?pwd=abc."])
    equal(zoom?.absoluteString, "https://us02web.zoom.us/j/123456789?pwd=abc", "zoom link, trailing dot dropped")
    equal(Riunione.link(in: ["https://meet.google.com/abc-defg-hij"])?.host, "meet.google.com", "meet link")
    check(Riunione.link(in: ["https://example.com/j/1", "nothing here"]) == nil, "unknown hosts ignored")

    check(!Riunione.visibile(inizio: at(10), fine: at(11), ora: at(9, 54)), "hidden 6 min before")
    check(Riunione.visibile(inizio: at(10), fine: at(11), ora: at(9, 55)), "shown 5 min before")
    check(!Riunione.visibile(inizio: at(10), fine: at(11), ora: at(10, 10)), "hidden 10 min after start")
    equal(Riunione.scegli([(inizio: at(9), fine: at(12)), (inizio: at(10), fine: at(11))], ora: at(9, 58)), 1, "a long block doesn't hide the next meeting")
    equal(Riunione.quantoManca(inizio: at(10), ora: at(9, 56), inglese: true), "in 4 min")
    equal(Riunione.quantoManca(inizio: at(10), ora: at(10, 1), inglese: true), "now")
}

func testTileLayout() {
    var l = TileLayout.standard
    l.resize("music", to: 9)
    equal(l.tiles[0].cells, TileLayout.maxCells, "resize is clamped")
    l.move("timer", to: 0)
    equal(l.tiles.first?.id, "timer", "move to front")
    l.add("timer")
    equal(l.tiles.filter { $0.id == "timer" }.count, 1, "no duplicates on add")
    l.remove("timer")
    check(!l.tiles.contains { $0.id == "timer" }, "remove")

    equal(TileLayout.decode(Data("garbage".utf8)), .standard, "corrupt data falls back to standard")
    let dup = TileLayout(tiles: [Tile(id: "a", cells: 0), Tile(id: "a", cells: 2)])
    equal(TileLayout.decode(dup.encode()).tiles, [Tile(id: "a", cells: 1)], "decode drops duplicates and clamps")
    equal(TileLayout(tiles: [Tile(id: "a", cells: 2), Tile(id: "b", cells: 1)]).width(cell: 84, gap: 8), 84 * 3 + 8 * 2, "row width")
}

func testLyrics() {
    let lines = LRC.parse("[00:12.50] second\n[00:01.00] first\nno stamp\n[00:20.00]   ")
    equal(lines.map(\.text), ["first", "second"], "sorted, junk dropped")
    equal(LRC.index(at: 0.5, in: lines), nil, "before the first line")
    equal(LRC.index(at: 13, in: lines), 1, "current line")
}

func testGridPaging() {
    equal(GridPaging.pages(count: 0, perPage: 10), 1, "at least one page")
    equal(GridPaging.pages(count: 21, perPage: 10), 3)
    equal(GridPaging.range(page: 2, count: 21, perPage: 10), 20..<21)
    equal(GridPaging.clamp(page: 9, count: 21, perPage: 10), 2)
}
