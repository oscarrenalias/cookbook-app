import Foundation

public enum AisleConfigParser {
    public static func parse(_ input: String) -> AisleConfig {
        var sections: [AisleSection] = []
        var currentSectionName: String?
        var currentItems: [AisleItem] = []

        func flushSection() {
            guard let sectionName = currentSectionName else { return }
            sections.append(AisleSection(name: sectionName, items: currentItems))
            currentSectionName = nil
            currentItems = []
        }

        for rawLine in input.components(separatedBy: .newlines) {
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty || trimmedLine.hasPrefix("--") {
                continue
            }

            if
                trimmedLine.hasPrefix("["),
                trimmedLine.hasSuffix("]"),
                trimmedLine.count >= 2
            {
                let name = trimmedLine
                    .dropFirst()
                    .dropLast()
                    .trimmingCharacters(in: .whitespaces)
                flushSection()
                currentSectionName = name
                continue
            }

            guard currentSectionName != nil else {
                continue
            }

            let tokens = trimmedLine
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            guard let canonical = tokens.first, !canonical.isEmpty else {
                continue
            }

            currentItems.append(AisleItem(canonical: canonical, aliases: Array(tokens.dropFirst())))
        }

        flushSection()

        return AisleConfig(sections: sections)
    }
}
