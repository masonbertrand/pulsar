// 27/10: which programs use the most processing power and memory, from one `ps` reading. Foundation only, tested in tests/.
import Foundation

enum ProcessUse {
    struct Row: Equatable {
        var name: String
        var cpu: Double          // percent of one core, like Activity Monitor (can pass 100 on a multi-core Mac)
        var mb: Double
        var isApp: Bool          // inside a .app bundle
    }

    /// `ps -axo %cpu=,rss=,comm=` → one row per program: helpers inside an app count for the app
    /// (Chrome's renderers are Chrome), anything else goes by its executable name.
    static func parse(_ ps: String) -> [Row] {
        var out: [String: Row] = [:]
        for line in ps.split(separator: "\n") {
            let p = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard p.count == 3, let cpu = Double(p[0].replacingOccurrences(of: ",", with: ".")), let kb = Double(p[1]) else { continue }
            let path = String(p[2])
            let name: String, app: Bool
            if let r = path.range(of: ".app/") {
                name = URL(fileURLWithPath: String(path[..<r.lowerBound])).lastPathComponent; app = true
            } else {
                name = URL(fileURLWithPath: path).lastPathComponent; app = false
            }
            guard !name.isEmpty, name != "ps" else { continue }      // not the reading itself
            out[name, default: Row(name: name, cpu: 0, mb: 0, isApp: app)].cpu += cpu
            out[name]!.mb += kb / 1024
        }
        return Array(out.values)
    }

    /// The busiest programs, highest CPU first; ties go by name so the list doesn't jump around.
    static func topCPU(_ rows: [Row], _ n: Int) -> [Row] {
        Array(rows.sorted { $0.cpu != $1.cpu ? $0.cpu > $1.cpu : $0.name < $1.name }.prefix(n))
    }

    /// The apps using the most memory (only .app bundles, as the tile always showed).
    static func topMemory(_ rows: [Row], _ n: Int) -> [Row] {
        Array(rows.filter(\.isApp).sorted { $0.mb > $1.mb }.prefix(n))
    }

    static func cpuText(_ v: Double) -> String { v >= 10 ? String(format: "%.0f%%", v) : String(format: "%.1f%%", v) }
    static func mbText(_ mb: Double) -> String { mb > 1024 ? String(format: "%.1f GB", mb / 1024) : String(format: "%.0f MB", mb) }
}
