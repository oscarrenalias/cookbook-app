import SwiftUI

struct ShoppingListCardView: View {
    let url: URL
    let modificationDate: Date?
    let itemCount: Int
    let doneCount: Int

    private var displayName: String {
        ShoppingListFiles.displayName(for: url)
    }

    private var relativeDate: String {
        guard let date = modificationDate else { return "" }
        return ShoppingListFiles.dateFormatter.localizedString(for: date, relativeTo: .now)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.tint)
                Image(systemName: "cart.fill")
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Shopping list")

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.headline)

                if !relativeDate.isEmpty {
                    Text(relativeDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label("\(itemCount) items", systemImage: "list.bullet")
                    Label("\(doneCount) done", systemImage: "checkmark.circle.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    List {
        ShoppingListCardView(
            url: URL(fileURLWithPath: "/tmp/Weekend BBQ.md"),
            modificationDate: Date(timeIntervalSinceNow: -2 * 86_400),
            itemCount: 14,
            doneCount: 5
        )
        ShoppingListCardView(
            url: URL(fileURLWithPath: "/tmp/Weekly Groceries.md"),
            modificationDate: Date(timeIntervalSinceNow: -7 * 86_400),
            itemCount: 0,
            doneCount: 0
        )
    }
}
