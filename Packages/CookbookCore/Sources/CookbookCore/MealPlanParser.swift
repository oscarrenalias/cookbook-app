import Foundation

/// Parser and serializer for Cooklang meal-plan (`.menu`) files.
///
/// Canonical example: `docs/examples/meal-plan.menu`.
public enum MealPlanParser {
    /// Parses meal-plan frontmatter, `== block ==` headings, optional section headings, checklist
    /// comments, and `@item{quantity}` entries without applying app-layer path or date resolution.
    public static func parse(_ input: String) -> MealPlan {
        let lines = input.components(separatedBy: "\n")
        let (metadataEntries, consumed) = parseFrontmatter(lines)

        var blocks: [MealPlanBlock] = []
        var currentBlockHeading: String?
        var currentSections: [MealPlanSection] = []
        var currentSectionName: String?
        var currentSectionItems: [MealPlanItem] = []
        var currentSectionIsOpen = false
        var commentStripper = CommentStripper()

        func flushSection() {
            guard currentSectionIsOpen else { return }
            currentSections.append(MealPlanSection(name: currentSectionName, items: currentSectionItems))
            currentSectionName = nil
            currentSectionItems = []
            currentSectionIsOpen = false
        }

        func flushBlock() {
            guard let heading = currentBlockHeading else { return }
            flushSection()
            blocks.append(MealPlanBlock(heading: heading, sections: currentSections))
            currentBlockHeading = nil
            currentSections = []
        }

        for rawLine in lines[consumed...] {
            let trimmedRawLine = rawLine.trimmingCharacters(in: .whitespaces)

            if !commentStripper.inBlockComment && trimmedRawLine.hasPrefix("--") {
                guard currentBlockHeading != nil else {
                    continue
                }

                if !currentSectionIsOpen {
                    currentSectionName = nil
                    currentSectionIsOpen = true
                }

                let comment = String(trimmedRawLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                currentSectionItems.append(.comment(comment))
                continue
            }

            let stripped = commentStripper.strip(rawLine)
            let trimmedLine = stripped.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty {
                continue
            }

            if let heading = parseBlockHeading(trimmedLine) {
                flushBlock()
                currentBlockHeading = heading
                continue
            }

            guard currentBlockHeading != nil else {
                continue
            }

            if let sectionName = parseSectionHeader(trimmedLine) {
                flushSection()
                currentSectionName = sectionName
                currentSectionIsOpen = true
                continue
            }

            guard let item = parseItem(trimmedLine) else {
                continue
            }

            if !currentSectionIsOpen {
                currentSectionName = nil
                currentSectionIsOpen = true
            }

            currentSectionItems.append(item)
        }

        flushBlock()

        return MealPlan(metadata: Metadata(metadataEntries), blocks: blocks)
    }

    /// Serializes the parsed meal-plan structure back into `.menu` text using CookbookCore's model.
    public static func serialise(_ plan: MealPlan) -> String {
        var lines: [String] = []

        if !plan.metadata.allEntries.isEmpty {
            lines.append("---")
            for entry in plan.metadata.allEntries {
                lines.append("\(entry.key): \(entry.value)")
            }
            lines.append("---")
        }

        for block in plan.blocks {
            if !lines.isEmpty {
                lines.append("")
            }

            lines.append("== \(block.heading) ==")

            for (sectionIndex, section) in block.sections.enumerated() {
                if sectionIndex > 0 {
                    lines.append("")
                }

                if let name = section.name {
                    lines.append("\(name):")
                }

                for item in section.items {
                    lines.append(serialise(item))
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func parseBlockHeading(_ line: String) -> String? {
        guard line.hasPrefix("=="), line.hasSuffix("=="), line.count >= 4 else {
            return nil
        }

        let start = line.index(line.startIndex, offsetBy: 2)
        let end = line.index(line.endIndex, offsetBy: -2)
        let heading = String(line[start..<end]).trimmingCharacters(in: .whitespaces)
        return heading.isEmpty ? nil : heading
    }

    private static func parseSectionHeader(_ line: String) -> String? {
        guard line.hasSuffix(":") else {
            return nil
        }

        let name = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private static func parseItem(_ line: String) -> MealPlanItem? {
        guard line.hasPrefix("@") else {
            return nil
        }

        var parser = Parser()
        let candidate = line.contains("{") ? line : "\(line){}"

        guard
            let step = try? parser.parseRawStep(candidate),
            step.items.count == 1,
            case let .ingredient(index) = step.items[0],
            parser.ingredients.indices.contains(index)
        else {
            return nil
        }

        let ingredient = parser.ingredients[index]

        if ingredient.name.contains("/") {
            return .recipe(MealPlanRecipe(path: ingredient.name, quantity: ingredient.quantity))
        }

        return .ingredient(MealPlanIngredient(name: ingredient.name, quantity: ingredient.quantity))
    }

    private static func parseFrontmatter(_ lines: [String]) -> (entries: [(key: String, value: String)], consumed: Int) {
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

            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let rest = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

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

        return ([], 0)
    }

    private static func serialise(_ item: MealPlanItem) -> String {
        switch item {
        case let .recipe(recipe):
            return "@\(recipe.path)\(serialise(quantity: recipe.quantity))"
        case let .ingredient(ingredient):
            return "@\(ingredient.name)\(serialise(quantity: ingredient.quantity))"
        case let .comment(comment):
            return comment.isEmpty ? "--" : "-- \(comment)"
        case let .text(text):
            return text
        }
    }

    private static func serialise(quantity: Quantity?) -> String {
        guard let quantity else {
            return ""
        }

        let value: String = switch quantity.value {
        case let .number(number):
            if number.isFinite, number.rounded() == number {
                String(Int(number))
            } else {
                String(number)
            }
        case let .text(text):
            text
        }

        if let unit = quantity.unit, !unit.isEmpty {
            return "{\(value)%\(unit)}"
        }

        return "{\(value)}"
    }
}
