import Foundation

/// Resolves API image strings into loadable `https` URLs (handles relative `/storage/...` paths).
enum MediaURL {
    nonisolated static func httpsURL(from string: String?) -> URL? {
        let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        if let url = URL(string: raw), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return url
        }
        var path = raw
        if path.hasPrefix("//"), let u = URL(string: "https:\(path)") {
            return u
        }
        if !path.hasPrefix("/") {
            path = "/" + path
        }
        let base = AppConfig.supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: base + path)
    }
}
