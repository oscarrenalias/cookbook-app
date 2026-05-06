import SwiftUI

struct MealPlanCardView: View {
    let url: URL
    let modificationDate: Date?
    let recipeCount: Int

    private var displayName: String {
        MealPlanFiles.displayName(for: url)
    }

    private var relativeDate: String {
        guard let date = modificationDate else { return "" }
        return MealPlanFiles.dateFormatter.localizedString(for: date, relativeTo: .now)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.tint)
                Image(systemName: "calendar")
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Meal plan")

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.headline)

                if !relativeDate.isEmpty {
                    Text(relativeDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                    Text("\(recipeCount) recipes")
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
        MealPlanCardView(
            url: URL(fileURLWithPath: "/tmp/Busy Week.menu"),
            modificationDate: Date(timeIntervalSinceNow: -2 * 86_400),
            recipeCount: 7
        )
        MealPlanCardView(
            url: URL(fileURLWithPath: "/tmp/Finger Food Party.menu"),
            modificationDate: Date(timeIntervalSinceNow: -14 * 86_400),
            recipeCount: 0
        )
    }
}
