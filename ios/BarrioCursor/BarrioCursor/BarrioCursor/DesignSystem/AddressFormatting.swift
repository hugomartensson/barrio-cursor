import Foundation

/// Short location label for cards (neighborhood / district), not full postal addresses.
enum AddressFormatting {
    /// Prefer explicit neighborhood; otherwise derive a short label from a full address string.
    static func shortLocationLabel(neighborhood: String?, address: String) -> String {
        if let n = neighborhood?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            return n
        }
        return shortLocationLabel(from: address)
    }

    static func shortLocationLabel(from address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return trimmed }

        if parts.count >= 2 {
            let second = parts[1]
            // Skip segment that is only a postal code + city blob like "08004 Barcelona"
            if second.range(of: #"^\d{5}\s"#, options: .regularExpression) != nil, parts.count >= 3 {
                return parts[2]
            }
            return second
        }

        let first = parts[0]
        let withoutPostal = first.replacingOccurrences(of: #"^\d{5}\s*"#, with: "", options: .regularExpression)
        return withoutPostal.isEmpty ? first : withoutPostal
    }

    // MARK: - City-only label (Discover cards)

    private static let countrySuffixes: Set<String> = [
        "spain", "sverige", "sweden", "france", "germany", "italy", "portugal", "norway", "denmark", "finland",
        "united kingdom", "uk", "usa", "united states", "netherlands", "belgium", "austria", "switzerland",
        "poland", "catalonia", "catalunya", "españa", "espana"
    ]

    /// Stable city name for cards, e.g. "Stockholm", "Barcelona" — avoids postal codes and country-only fallbacks.
    static func cityName(neighborhood: String?, address: String) -> String {
        let addr = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !addr.isEmpty else {
            if let n = neighborhood?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                return stripPostalPrefix(from: n) ?? n
            }
            return ""
        }

        let lower = addr.lowercased()
        let knownCities: [(needle: String, display: String)] = [
            ("stockholm", "Stockholm"),
            ("göteborg", "Göteborg"),
            ("gothenburg", "Göteborg"),
            ("malmö", "Malmö"),
            ("malmo", "Malmö"),
            ("uppsala", "Uppsala"),
            ("barcelona", "Barcelona"),
            ("l'hospitalet", "L'Hospitalet"),
            ("madrid", "Madrid"),
            ("london", "London"),
            ("paris", "Paris"),
        ]
        for pair in knownCities where lower.contains(pair.needle) {
            return pair.display
        }

        var segments = addr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        while let last = segments.last, countrySuffixes.contains(last.lowercased()) {
            segments.removeLast()
        }
        guard var candidate = segments.last else {
            if let n = neighborhood?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                return stripPostalPrefix(from: n) ?? n
            }
            return ""
        }
        if countrySuffixes.contains(candidate.lowercased()) { return "" }
        if let stripped = stripPostalPrefix(from: candidate) {
            candidate = stripped
        }
        if countrySuffixes.contains(candidate.lowercased()) { return "" }
        return candidate
    }

    // MARK: - Street address (detail views)

    /// Returns the street portion of a full address, e.g. "Carrer de Marià Aguiló 37".
    /// Strips trailing postal code segments, city, and country so only the street remains.
    static func streetAddress(from address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let parts = trimmed.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = parts.first else { return trimmed }
        // The first segment is the street name + number; strip any leading/trailing postal digits
        let stripped = first.replacingOccurrences(of: #"^\d{5}\s*"#, with: "", options: .regularExpression)
        return stripped.isEmpty ? first : stripped
    }

    /// Formats the detail location line: "Street, Neighborhood" e.g. "Carrer de Marià Aguiló 37, Poblenou".
    static func detailLocationLine(neighborhood: String?, address: String) -> String {
        let street = streetAddress(from: address)
        let nbhd = neighborhood?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if street.isEmpty && nbhd.isEmpty { return address }
        if street.isEmpty { return nbhd }
        if nbhd.isEmpty { return street }
        return "\(street), \(nbhd)"
    }

    /// Strips leading postal codes (ES `12345`, SE `123 45` / `12345`) from one address segment.
    private static func stripPostalPrefix(from segment: String) -> String? {
        let s = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.range(of: #"^\d{5}\s+.+$"#, options: .regularExpression) != nil {
            return s.replacingOccurrences(of: #"^\d{5}\s+"#, with: "", options: .regularExpression)
        }
        if s.range(of: #"^\d{3}\s?\d{2}\s+.+$"#, options: .regularExpression) != nil {
            return s.replacingOccurrences(of: #"^\d{3}\s?\d{2}\s+"#, with: "", options: .regularExpression)
        }
        return nil
    }
}
