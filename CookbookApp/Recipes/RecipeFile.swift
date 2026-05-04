import Foundation

struct RecipeFile: Identifiable, Equatable {
    let url: URL
    let thumbnailURL: URL?

    var id: URL { url }

    var displayName: String {
        let filename = url.lastPathComponent
        let ext = url.pathExtension
        if ext.lowercased() == "cook" {
            return String(filename.dropLast(ext.count + 1))
        }
        return filename
    }
}
