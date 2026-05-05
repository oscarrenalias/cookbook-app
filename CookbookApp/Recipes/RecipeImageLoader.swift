import SwiftUI
import UIKit

enum RecipeImageLoader {
    private static let extensions = ["jpg", "jpeg", "png", "heic"]

    static func loadImage(for recipeURL: URL) async -> Image? {
        await Task.detached(priority: .utility) {
            let didStart = recipeURL.startAccessingSecurityScopedResource()
            defer {
                if didStart {
                    recipeURL.stopAccessingSecurityScopedResource()
                }
            }

            let base = recipeURL.deletingPathExtension()
            for ext in RecipeImageLoader.extensions {
                let candidate = base.appendingPathExtension(ext)
                guard FileManager.default.fileExists(atPath: candidate.path),
                      let data = try? Data(contentsOf: candidate),
                      let uiImage = UIImage(data: data) else {
                    continue
                }
                return Image(uiImage: uiImage)
            }
            return nil
        }.value
    }
}
