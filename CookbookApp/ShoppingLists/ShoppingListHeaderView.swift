import SwiftUI

struct ShoppingListHeaderView: View {
    let label: String
    let lines: [String]
    @SceneStorage private var isExpanded: Bool

    init(label: String, lines: [String], storageKey: String) {
        self.label = label
        self.lines = lines
        _isExpanded = SceneStorage(wrappedValue: true, storageKey)
    }

    var body: some View {
        Section {
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
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
                    Text(label)
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
        if let attributed = try? AttributedString(markdown: line) {
            Text(attributed)
                .font(.subheadline)
        } else {
            Text(line)
                .font(.subheadline)
        }
    }
}
