import SwiftUI

struct ShoppingListHeaderView: View {
    let content: HeaderContent
    @SceneStorage private var isExpanded: Bool

    init(content: HeaderContent, storageKey: String) {
        self.content = content
        _isExpanded = SceneStorage(wrappedValue: true, storageKey)
    }

    var body: some View {
        Section {
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(bodyLines.enumerated()), id: \.offset) { _, line in
                        lineView(for: line)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(disclosureLabel)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func lineView(for line: String) -> some View {
        if line.hasPrefix("## ") {
            Text(String(line.dropFirst(3)))
                .font(.subheadline)
                .fontWeight(.semibold)
        } else if let attributed = try? AttributedString(markdown: line) {
            Text(attributed)
                .font(.subheadline)
        } else {
            Text(line)
                .font(.subheadline)
        }
    }

    private var disclosureLabel: String {
        content.firstHeading ?? "Notes"
    }

    private var bodyLines: [String] {
        var didSkip = false
        return content.markdown
            .components(separatedBy: "\n")
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { return false }
                if !didSkip,
                   let heading = content.firstHeading,
                   trimmed == "## \(heading)" {
                    didSkip = true
                    return false
                }
                return true
            }
    }
}
