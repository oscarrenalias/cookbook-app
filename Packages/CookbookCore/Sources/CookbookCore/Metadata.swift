import Foundation

public struct Metadata: Sendable {
    private let storage: [(key: String, value: String)]

    public init(_ entries: [(key: String, value: String)] = []) {
        self.storage = entries
    }

    public subscript(key: String) -> String? {
        storage.first { $0.key == key }?.value
    }

    public var servings: [Int]? {
        guard let raw = self["servings"] else { return nil }
        let parts = raw
            .components(separatedBy: CharacterSet(charactersIn: ",").union(.whitespaces))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let ints = parts.compactMap(Int.init)
        return ints.isEmpty ? nil : ints
    }

    public var title: String? {
        self["title"]
    }

    public var tags: [String] {
        guard let raw = self["tags"] else { return [] }
        return raw
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    public var normalizedTags: [String] {
        tags.map { tag in
            tag.lowercased()
               .components(separatedBy: .whitespaces)
               .filter { !$0.isEmpty }
               .joined(separator: " ")
        }
    }

    /// Parses a time value stored under `key` and returns total minutes.
    /// Recognized formats: plain integer (minutes), "30m/min/mins/minute/minutes",
    /// "1h/hr/hrs/hour/hours", combinations ("1h 30m", "1 hour 30 minutes"),
    /// and colon notation ("1:30"). Returns `nil` for absent, empty, or unrecognized values.
    public func minutes(forKey key: String) -> Int? {
        guard let raw = self[key] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Self.parseMinutes(from: trimmed)
    }

    public var allEntries: [(key: String, value: String)] {
        storage
    }

    private static func parseMinutes(from string: String) -> Int? {
        if let n = Int(string) { return n }

        let s = string.lowercased()

        let colonParts = s.components(separatedBy: ":")
        if colonParts.count == 2,
           let h = Int(colonParts[0].trimmingCharacters(in: .whitespaces)),
           let m = Int(colonParts[1].trimmingCharacters(in: .whitespaces)),
           m < 60 {
            return h * 60 + m
        }

        var total = 0
        var found = false

        if let h = firstCapture(in: s, pattern: #"(\d+)\s*(?:hours?|hrs?|h)"#) {
            total += h * 60
            found = true
        }
        if let m = firstCapture(in: s, pattern: #"(\d+)\s*(?:minutes?|mins?|m)"#) {
            total += m
            found = true
        }

        return found ? total : nil
    }

    private static func firstCapture(in string: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: string) else { return nil }
        return Int(string[range])
    }
}

extension Metadata: Equatable {
    public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
        guard lhs.storage.count == rhs.storage.count else { return false }
        return zip(lhs.storage, rhs.storage).allSatisfy { $0.key == $1.key && $0.value == $1.value }
    }
}
