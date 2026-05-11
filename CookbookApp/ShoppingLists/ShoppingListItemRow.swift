import SwiftUI
import CookbookCore

struct ShoppingListItemRow: View {
    let entry: ShoppingListEntry
    var onToggle: () -> Void
    var onDelete: () -> Void
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle()
            } label: {
                Image(systemName: entry.checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(entry.checked ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.checked ? "Mark as incomplete" : "Mark as complete")

            itemText
                .frame(maxWidth: .infinity, alignment: .leading)
}
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityLabel("Delete item")

            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.gray)
            .accessibilityLabel("Edit item")
        }
    }

    @ViewBuilder
    private var itemText: some View {
        let attributed = try? AttributedString(markdown: entry.text)
        if let attributed {
            Text(attributed)
                .strikethrough(entry.checked)
                .foregroundStyle(entry.checked ? Color.secondary : Color.primary)
        } else {
            Text(entry.text)
                .strikethrough(entry.checked)
                .foregroundStyle(entry.checked ? Color.secondary : Color.primary)
        }
    }
}

#Preview {
    List {
        ShoppingListItemRow(
            entry: ShoppingListEntry(text: "*300 g* broccoli", checked: false),
            onToggle: {},
            onDelete: {},
            onEdit: {}
        )
        ShoppingListItemRow(
            entry: ShoppingListEntry(text: "*1 piece* courgette", checked: true),
            onToggle: {},
            onDelete: {},
            onEdit: {}
        )
        ShoppingListItemRow(
            entry: ShoppingListEntry(text: "plain butter", checked: false),
            onToggle: {},
            onDelete: {},
            onEdit: {}
        )
    }
}
