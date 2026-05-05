import SwiftUI

struct RecipeHeroHeader: View {
    let recipe: RecipeFile
    let onDismiss: () -> Void

    private let heroHeight: CGFloat = 240

    @State private var heroImage: Image?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            imageOrFallback
            gradient
            titleLabel
        }
        .frame(height: heroHeight)
        .clipped()
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
                .frame(maxWidth: .infinity)
        } else {
            ZStack {
                Rectangle()
                    .fill(.tint)
                Image(systemName: "fork.knife")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var gradient: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.65)],
            startPoint: .center,
            endPoint: .bottom
        )
    }

    private var titleLabel: some View {
        Text(recipe.displayName)
            .font(.title)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding()
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
            recipe: RecipeFile(
                url: URL(fileURLWithPath: "/tmp/Creamy Garlic Chicken Pasta.cook"),
                thumbnailURL: nil
            ),
            onDismiss: {}
        )
        Spacer()
    }
}
