import SwiftUI

struct MealPlansTab: View {
    var body: some View {
        EmptyStateView(
            systemImage: "calendar",
            title: "Meal Plans",
            subtitle: "No meal plans yet."
        )
    }
}

#Preview {
    MealPlansTab()
}
