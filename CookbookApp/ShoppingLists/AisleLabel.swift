import SwiftUI

/// A small row showing an aisle's icon (per `AisleIconMap`) alongside its
/// capitalized name. Used inside the aisle picker when rendered as a
/// `navigationLink`-style Picker — each row is a standard SwiftUI List row
/// where explicit `.frame()` on asset images is respected. (The `.menu`
/// picker style strips frame constraints from non-SF-Symbol images in its
/// collapsed chip, which is why we avoid it for aisle pickers.)
struct AisleLabel: View {
    let aisleName: String

    var body: some View {
        HStack(spacing: 10) {
            aisleIcon
                .frame(width: 22, height: 22)
            Text(aisleName.localizedCapitalized)
        }
    }

    @ViewBuilder
    private var aisleIcon: some View {
        switch AisleIconMap.source(for: aisleName) {
        case .system(let symbol):
            Image(systemName: symbol)
                .foregroundStyle(.tint)
        case .asset(let asset):
            Image(asset)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(.tint)
        }
    }
}
