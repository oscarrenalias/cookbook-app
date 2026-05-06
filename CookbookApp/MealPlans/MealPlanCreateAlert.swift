import SwiftUI

struct MealPlanCreateAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var name: String
    @Binding var duplicateNameError: Bool
    let onCreate: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("New meal plan", isPresented: $isPresented) {
                TextField("Name (e.g., 'Weekday meals')", text: $name)
                Button("Create", action: onCreate)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) {
                    name = ""
                    duplicateNameError = false
                }
            } message: {
                if duplicateNameError {
                    Text("A plan with that name already exists.")
                }
            }
    }
}

extension View {
    func mealPlanCreateAlert(
        isPresented: Binding<Bool>,
        name: Binding<String>,
        duplicateNameError: Binding<Bool>,
        onCreate: @escaping () -> Void
    ) -> some View {
        modifier(MealPlanCreateAlertModifier(
            isPresented: isPresented,
            name: name,
            duplicateNameError: duplicateNameError,
            onCreate: onCreate
        ))
    }
}
