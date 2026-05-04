import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Cookbook")
                .font(.title)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
