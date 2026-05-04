public struct CooklangParser {
    public let extensions: Extensions
    public let converter: Converter

    public init(extensions: Extensions = .canonical, converter: Converter = .empty) {
        self.extensions = extensions
        self.converter = converter
    }

    public static let canonical = CooklangParser()
    public static let extended = CooklangParser(extensions: .all)

    public func parse(_ input: String) throws -> Recipe {
        let lines = input.components(separatedBy: "\n")

        var metadataEntries: [(key: String, value: String)] = []
        var sections: [Section] = []
        var currentSectionName: String? = nil
        var currentStepLines: [String] = []
        var currentSectionContent: [Content] = []
        var inMetadataRegion = true
        var commentStripper = CommentStripper()
        var inlineParser = Parser()

        for line in lines {
            let stripped = commentStripper.strip(line)
            let trimmed = stripped.trimmingCharacters(in: .whitespaces)

            if inMetadataRegion {
                if trimmed.isEmpty {
                    inMetadataRegion = false
                    continue
                }
                if trimmed.hasPrefix(">>") {
                    let rest = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if let colonIdx = rest.firstIndex(of: ":") {
                        let key = String(rest[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                        let value = String(rest[rest.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                        if !key.isEmpty {
                            metadataEntries.append((key: key, value: value))
                        }
                    }
                    continue
                }
                inMetadataRegion = false
            }

            if trimmed.isEmpty {
                if !currentStepLines.isEmpty {
                    let step = try inlineParser.parseRawStep(currentStepLines.joined(separator: " "))
                    currentSectionContent.append(.step(step))
                    currentStepLines = []
                }
                continue
            }

            if trimmed.hasPrefix("==") && trimmed.hasSuffix("==") {
                let inner = String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
                if !inner.isEmpty {
                    if !currentStepLines.isEmpty {
                        let step = try inlineParser.parseRawStep(currentStepLines.joined(separator: " "))
                        currentSectionContent.append(.step(step))
                        currentStepLines = []
                    }
                    if !currentSectionContent.isEmpty || currentSectionName != nil {
                        sections.append(Section(name: currentSectionName, content: currentSectionContent))
                        currentSectionContent = []
                        currentSectionName = nil
                    }
                    currentSectionName = inner
                    continue
                }
            }

            currentStepLines.append(trimmed)
        }

        if !currentStepLines.isEmpty {
            let step = try inlineParser.parseRawStep(currentStepLines.joined(separator: " "))
            currentSectionContent.append(.step(step))
        }

        if !currentSectionContent.isEmpty || currentSectionName != nil {
            sections.append(Section(name: currentSectionName, content: currentSectionContent))
        }

        return Recipe(
            metadata: Metadata(metadataEntries),
            sections: sections,
            ingredients: inlineParser.ingredients,
            cookware: inlineParser.cookware,
            timers: inlineParser.timers
        )
    }

    public func parseMetadata(_ input: String) throws -> Metadata {
        return try parse(input).metadata
    }
}
