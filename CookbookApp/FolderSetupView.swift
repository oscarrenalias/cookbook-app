import SwiftUI

struct FolderSetupView: View {
    let store: RecipesFolderStore
    @State private var isPickerPresented = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("Please select a folder with recipes")
                .font(.title2)
                .multilineTextAlignment(.center)

            Text("Cookbook reads recipes from a folder you pick — on your device, in iCloud Drive, or any provider you have set up.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Button("Choose folder…") {
                isPickerPresented = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Choose recipes folder")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $isPickerPresented) {
            RecipesFolderPicker(store: store)
        }
    }
}

#Preview {
    FolderSetupView(store: RecipesFolderStore())
}
