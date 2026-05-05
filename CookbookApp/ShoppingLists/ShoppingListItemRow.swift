import SwiftUI
import CookbookCore

struct ShoppingListItemRow: View {
    let item: ShoppingListItem
    var onToggle: () -> Void
    var onDelete: () -> Void
    var onUpdate: (String) -> Void

    @State private var showEditAlert = false
    @State private var editText = ""

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle()
            } label: {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.checked ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.checked ? "Mark as incomplete" : "Mark as complete")

            itemText
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "line.3.horizontal")
                .font(.body)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityLabel("Delete item")

            Button {
                editText = item.text
                showEditAlert = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.gray)
            .accessibilityLabel("Edit item")
        }
        .alert("Edit item", isPresented: $showEditAlert) {
            TextField("Item text", text: $editText)
            Button("Save") {
                let trimmed = editText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    onUpdate(trimmed)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var itemText: some View {
        let attributed = try? AttributedString(markdown: item.text)
        if let attributed {
            Text(attributed)
                .strikethrough(item.checked)
                .foregroundStyle(item.checked ? Color.secondary : Color.primary)
        } else {
            Text(item.text)
                .strikethrough(item.checked)
                .foregroundStyle(item.checked ? Color.secondary : Color.primary)
        }
    }
}

#Preview {
    List {
        ShoppingListItemRow(
            item: ShoppingListItem(lineIndex: 0, checked: false, text: "*300 g* broccoli"),
            onToggle: {},
            onDelete: {},
            onUpdate: { _ in }
        )
        ShoppingListItemRow(
            item: ShoppingListItem(lineIndex: 1, checked: true, text: "*1 piece* courgette"),
            onToggle: {},
            onDelete: {},
            onUpdate: { _ in }
        )
        ShoppingListItemRow(
            item: ShoppingListItem(lineIndex: 2, checked: false, text: "plain butter"),
            onToggle: {},
            onDelete: {},
            onUpdate: { _ in }
        )
    }
}
