import SwiftUI

struct RecipeRowView: View {
    let recipe: RecipeFile

    var body: some View {
        HStack {
            RecipeThumbnailView(thumbnailURL: recipe.thumbnailURL)
                .frame(width: 56, height: 56)
            Text(recipe.displayName)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
    }
}
