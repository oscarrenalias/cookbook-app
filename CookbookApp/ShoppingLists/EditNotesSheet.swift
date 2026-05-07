import SwiftUI
import CookbookCore

struct EditNotesSheet: View {
    let listName: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var notesText: String
    @FocusState private var editorFocused: Bool

    init(initialNotes: String, listName: String, onSave: @escaping (String) -> Void) {
        self.listName = listName
        self.onSave = onSave
        _notesText = State(initialValue: initialNotes)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $notesText)
                .focused($editorFocused)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal)
                .accessibilityLabel("Editing notes for \(listName)")
                .navigationTitle("Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            handleSave()
                        }
                    }
                }
                .onAppear {
                    editorFocused = true
                }
        }
    }

    private func handleSave() {
        onSave(notesText)
        dismiss()
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            EditNotesSheet(
                initialNotes: "- Pick up from Whole Foods\n- Check for weekly specials",
                listName: "Weekend Groceries"
            ) { _ in }
        }
}
