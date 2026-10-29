// 29/10: pure helpers for the built-out tabs and the new tiles: sorting Downloads by kind, finding a time zone from a
// city, a colour's hex code, and the mail link to a meeting's attendees. Foundation only, tested in tests/.
import Foundation

enum RiordinaDownload {
    /// The subfolder a file goes to when Downloads is tidied, by its extension. nil = leave it (folders, partial downloads).
    static func cartella(_ nome: String, isCartella: Bool) -> String? {
        if isCartella { return nil }
        let ext = (nome as NSString).pathExtension.lowercased()
        if ["crdownload", "download", "part", "partial"].contains(ext) { return nil }
        switch ext {
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "svg", "tiff", "bmp", "avif": return "Images"
        case "pdf", "doc", "docx", "pages", "txt", "rtf", "md", "xls", "xlsx", "numbers", "csv", "ppt", "pptx", "key", "epub": return "Documents"
        case "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz": return "Archives"
        case "dmg", "pkg", "app", "iso": return "Installers"
        case "mp4", "mov", "m4v", "avi", "mkv", "webm": return "Videos"
        case "mp3", "wav", "aiff", "aif", "m4a", "flac", "ogg": return "Audio"
        default: return "Other"
        }
    }

    /// The folders tidying creates; files already in them stay put.
    static let cartelle: Set<String> = ["Images", "Documents", "Archives", "Installers", "Videos", "Audio", "Other"]
}

enum FusoOrario {
    /// A time zone from what someone types: "Tokyo", "new york", "Europe/Paris", "PST". nil if nothing matches.
    static func cerca(_ testo: String, tra noti: [String] = TimeZone.knownTimeZoneIdentifiers) -> String? {
        let t = testo.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        if noti.contains(t) { return t }
        if TimeZone(abbreviation: t.uppercased()) != nil, t.count <= 5 { return TimeZone(abbreviation: t.uppercased())?.identifier }
        let chiave = t.lowercased().replacingOccurrences(of: " ", with: "_")
        return noti.first { $0.lowercased().hasSuffix("/" + chiave) } ?? noti.first { $0.lowercased().contains(chiave) }
    }

    /// The city part of an identifier: "America/New_York" → "New York".
    static func nome(_ id: String) -> String {
        (id.split(separator: "/").last.map(String.init) ?? id).replacingOccurrences(of: "_", with: " ")
    }
}

enum Colore {
    /// "#1A2B3C" from 0...1 components.
    static func hex(_ r: Double, _ g: Double, _ b: Double) -> String {
        func c(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }
}

enum Invitati {
    /// A mailto link to the attendees, with the meeting's title as the subject. nil without addresses.
    static func mail(_ indirizzi: [String], oggetto: String) -> URL? {
        let a = indirizzi.filter { $0.contains("@") }
        guard !a.isEmpty else { return nil }
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = a.joined(separator: ",")
        c.queryItems = [URLQueryItem(name: "subject", value: oggetto)]
        return c.url
    }
}
