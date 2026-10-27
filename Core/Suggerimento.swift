// 27/10: a name that appears when you hover a button, so you know what you're about to click.
// macOS tooltips (.help) show only in the app you're using, and Pulsar's island is hovered while another app is
// in front, so they rarely appeared. This label is drawn by the island itself, above the tiles, after a short pause.
// Use `.hint("Name")` on a button and `.hintLayer()` once on the panel that holds it. It keeps `.help` too.
import SwiftUI

struct HintItem {
    let text: String
    let anchor: Anchor<CGRect>
}

struct HintKey: PreferenceKey {
    static let defaultValue: [HintItem] = []
    static func reduce(value: inout [HintItem], nextValue: () -> [HintItem]) { value += nextValue() }
}

private struct HintModifier: ViewModifier {
    let text: String
    @State private var over = false
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .help(text)
            .onHover { h in
                over = h
                if h {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if over { shown = true } }
                } else {
                    shown = false
                }
            }
            .anchorPreference(key: HintKey.self, value: .bounds) { shown && !text.isEmpty ? [HintItem(text: text, anchor: $0)] : [] }
    }
}

struct HintLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11)).foregroundStyle(Volta.t1).lineLimit(1)
            .padding(.horizontal, 9).frame(height: 22)
            .background(Capsule().fill(Volta.pill).background(Capsule().fill(Volta.body)))
            .fixedSize()
    }
}

extension View {
    func hint(_ text: String) -> some View { modifier(HintModifier(text: text)) }

    /// Draws the hovered button's name under it (above it near the bottom edge), over everything else in this view.
    func hintLayer() -> some View {
        overlayPreferenceValue(HintKey.self) { items in
            GeometryReader { g in
                if let it = items.last {
                    let r = g[it.anchor]
                    let below = r.maxY + 28 <= g.size.height
                    HintLabel(text: it.text)
                        .position(x: min(max(r.midX, 50), g.size.width - 50), y: below ? r.maxY + 14 : r.minY - 14)
                        .transition(.opacity)
                }
            }
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.12), value: items.last?.text)
        }
    }
}
