import Foundation
import CookbookCore

/// Pure helper that infers an aisle name from free-form item text.
///
/// Algorithm: trim → strip leading numeric quantity prefix → check stripped text
/// against AisleConfig canonical/alias → check last word as fallback → nil.
enum AisleAutoDetect {

    /// Returns the aisle name for `text` by consulting `config`, or `nil` when
    /// no match is found. Does not mutate any external state.
    static func detectAisle(for text: String, config: AisleConfig) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let candidate = strippingQuantityPrefix(from: trimmed)

        if let section = config.aisle(for: candidate) {
            return section.name
        }

        // Last-word fallback: only meaningful when candidate is multi-word.
        let words = candidate.split(separator: " ")
        if words.count > 1, let lastWord = words.last,
           let section = config.aisle(for: String(lastWord)) {
            return section.name
        }

        return nil
    }

    // Removes a leading numeric quantity prefix followed by whitespace.
    // Handles compact units (e.g. "500g flour") and space-separated numbers
    // (e.g. "2 lemons"). Returns the unchanged input when no numeric prefix
    // is present or when stripping would leave an empty string.
    private static func strippingQuantityPrefix(from text: String) -> String {
        // Pattern: leading digits, optional decimal part, optional compact unit letters, trailing space(s).
        let pattern = #"^\d+(?:\.\d+)?[a-zA-Z]*\s+"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            ),
            let range = Range(match.range, in: text)
        else {
            return text
        }
        let remaining = String(text[range.upperBound...])
        return remaining.isEmpty ? text : remaining
    }
}
