import SwiftUI

// MARK: - Cache

private final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 200
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

// MARK: - View

struct RecipeThumbnailView: View {
    let thumbnailURL: URL?

    @State private var image: UIImage?

    private let size: CGFloat = 56

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .task(id: thumbnailURL) {
            await loadImage()
        }
    }

    private var fallback: some View {
        ZStack {
            Rectangle()
                .fill(.tint)
            Image(systemName: "fork.knife")
                .foregroundStyle(.white)
        }
    }

    private func loadImage() async {
        guard let url = thumbnailURL else {
            image = nil
            return
        }

        if let cached = ThumbnailCache.shared.image(for: url) {
            image = cached
            return
        }

        let loaded = await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url),
                  let img = UIImage(data: data) else { return nil as UIImage? }
            return img
        }.value

        guard !Task.isCancelled else { return }

        if let loaded {
            ThumbnailCache.shared.store(loaded, for: url)
        }
        image = loaded
    }
}
