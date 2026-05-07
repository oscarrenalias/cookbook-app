import SwiftUI
import CookbookCore

struct RecipeHeroHeader: View {
    let recipe: RecipeEntry
    let onDismiss: () -> Void

    private let heroHeight: CGFloat = 260

    @State private var heroImage: Image?

    var body: some View {
        imageOrFallback
            .overlay(alignment: .bottom) {
                gradient
            }
            .overlay(alignment: .bottomLeading) {
                titleLabel
            }
            .overlay(alignment: .topLeading) {
                dismissButton
            }
            .task(id: recipe.url) {
                heroImage = await RecipeImageLoader.loadImage(for: recipe.url)
            }
    }

    @ViewBuilder
    private var imageOrFallback: some View {
        if let heroImage {
            heroImage
                .resizable()
                .scaledToFill()
                .frame(height: heroHeight)
                .clipped()
                .frame(maxWidth: .infinity)
        } else {
            ZStack {
                Rectangle()
                    .fill(.tint)
                Image(systemName: "fork.knife")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: heroHeight, maxHeight: heroHeight)
        }
    }

    private var gradient: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: heroHeight * 0.4)
    }

    private var titleLabel: some View {
        Text(recipe.displayName)
            .font(.title2)
            .bold()
            .foregroundStyle(.white)
            .padding(.horizontal)
            .padding(.bottom, 14)
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .background(.regularMaterial, in: Circle())
        }
        .accessibilityLabel("Dismiss")
        .padding()
    }
}

#Preview {
    VStack(spacing: 0) {
        RecipeHeroHeader(
            recipe: RecipeEntry(
                url: URL(fileURLWithPath: "/tmp/Creamy Garlic Chicken Pasta.cook"),
                thumbnailURL: nil,
                recipe: Recipe()
            ),
            onDismiss: {}
        )
        Spacer()
    }
}
