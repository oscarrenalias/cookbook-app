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

        let (metadataEntries, consumed) = parseFrontmatter(lines)
        var sections: [Section] = []
        var currentSectionName: String? = nil
        var currentStepLines: [String] = []
        var currentSectionContent: [Content] = []
        var commentStripper = CommentStripper()
        var inlineParser = Parser()

        for line in lines[consumed...] {
            let stripped = commentStripper.strip(line)
            let trimmed = stripped.trimmingCharacters(in: .whitespaces)

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

    // Detects and parses a YAML frontmatter block (--- ... ---) at the start of the input.
    // Leading blank lines before the opening --- are allowed. Scalar values are stored verbatim;
    // list values (key: followed by indented - item lines) are joined with ", ".
    // Returns parsed entries and the number of lines consumed (through the closing ---).
    // Returns ([], 0) when no valid frontmatter block is present.
    private func parseFrontmatter(_ lines: [String]) -> (entries: [(key: String, value: String)], consumed: Int) {
        var i = 0

        while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
            i += 1
        }

        guard i < lines.count && lines[i].trimmingCharacters(in: .whitespaces) == "---" else {
            return ([], 0)
        }
        i += 1

        var entries: [(key: String, value: String)] = []

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            if trimmed == "---" {
                return (entries, i + 1)
            }

            if let colonIdx = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let rest = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

                if !key.isEmpty {
                    if rest.isEmpty {
                        var listItems: [String] = []
                        var j = i + 1
                        while j < lines.count {
                            let next = lines[j].trimmingCharacters(in: .whitespaces)
                            if next.hasPrefix("- ") {
                                listItems.append(String(next.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                                j += 1
                            } else {
                                break
                            }
                        }
                        if !listItems.isEmpty {
                            entries.append((key: key, value: listItems.joined(separator: ", ")))
                            i = j
                            continue
                        }
                    } else {
                        entries.append((key: key, value: rest))
                    }
                }
            }

            i += 1
        }

        // Unclosed frontmatter block — treat as no frontmatter
        return ([], 0)
    }
}
