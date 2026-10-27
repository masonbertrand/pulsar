import Foundation

func testTileFlow() {
    let w: [CGFloat] = [176, 176, 84, 268, 84]          // 2, 2, 1, 3, 1 cells
    equal(TileFlow.rows(w, maxWidth: 10_000, gap: 8), [[0, 1, 2, 3, 4]], "everything on one row when it fits")
    equal(TileFlow.rows(w, maxWidth: 460, gap: 8), [[0, 1, 2], [3, 4]], "wraps when the next tile doesn't fit")
    equal(TileFlow.rows(w, maxWidth: 100, gap: 8), [[0], [1], [2], [3], [4]], "a tile wider than the screen still shows")
    equal(TileFlow.rows([], maxWidth: 500, gap: 8), [], "no tiles")
    equal(TileFlow.width([0, 1, 2], w, gap: 8), 176 + 176 + 84 + 16)

    let step: CGFloat = 96 + 8
    func drop(_ i: Int, _ dx: CGFloat, _ dy: CGFloat) -> Int {
        TileFlow.dropIndex(dragged: i, widths: w, maxWidth: 460, gap: 8, rowStep: step, dx: dx, dy: dy)
    }
    equal(drop(0, 0, 0), 0, "no movement stays put")
    equal(drop(0, 200, 0), 1, "one tile to the right")
    equal(drop(2, -500, 0), 0, "to the front of the row")
    equal(drop(0, 0, step), 2, "down a row at the same x: before the second row's first tile")
    equal(drop(4, -400, -step), 0, "up from the second row to the very front")
    equal(drop(3, 400, 5 * step), 4, "far below and to the right ends up last")

    var l = TileLayout(tiles: [Tile(id: "a", cells: 2), Tile(id: "b", cells: 2), Tile(id: "c", cells: 1), Tile(id: "d", cells: 3), Tile(id: "e", cells: 1)])
    l.move("a", to: drop(0, 0, step))
    equal(l.tiles.map(\.id), ["b", "c", "a", "d", "e"], "move applies the drop index")
}
