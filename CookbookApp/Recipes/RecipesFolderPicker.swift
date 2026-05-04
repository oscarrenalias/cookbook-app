import SwiftUI
import UniformTypeIdentifiers

struct RecipesFolderPicker: UIViewControllerRepresentable {
    let store: RecipesFolderStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let store: RecipesFolderStore

        init(store: RecipesFolderStore) {
            self.store = store
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            store.saveBookmark(for: url)
        }
    }
}
