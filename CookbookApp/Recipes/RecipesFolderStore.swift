import Foundation
import Observation

@Observable
final class RecipesFolderStore {
    private(set) var folderURL: URL?

    var folderName: String? {
        UserDefaults.standard.string(forKey: Keys.folderName)
    }

    private enum Keys {
        static let bookmark = "recipesFolderBookmark"
        static let folderName = "recipesFolderName"
    }

    init() {
        resolveBookmark()
    }

    private func resolveBookmark() {
        guard let data = UserDefaults.standard.data(forKey: Keys.bookmark) else {
            folderURL = nil
            return
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                clearBookmark()
                return
            }

            folderURL = url
        } catch {
            clearBookmark()
        }
    }

    private func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: Keys.bookmark)
        UserDefaults.standard.removeObject(forKey: Keys.folderName)
        folderURL = nil
    }

    func saveBookmark(for url: URL) {
        do {
            _ = url.startAccessingSecurityScopedResource()
            let data = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            url.stopAccessingSecurityScopedResource()

            UserDefaults.standard.set(data, forKey: Keys.bookmark)
            UserDefaults.standard.set(url.lastPathComponent, forKey: Keys.folderName)
            resolveBookmark()
        } catch {
            clearBookmark()
        }
    }
}
