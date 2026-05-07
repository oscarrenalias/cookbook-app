import SwiftUI

struct ShoppingListHeaderView: View {
    let label: String
    let lines: [String]
    var onEdit: (() -> Void)? = nil
    @SceneStorage private var isExpanded: Bool

    init(label: String, lines: [String], storageKey: String, onEdit: (() -> Void)? = nil) {
        self.label = label
        self.lines = lines
        self.onEdit = onEdit
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
            HStack(spacing: 6) {
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

                if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit notes")
                }
            }
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
