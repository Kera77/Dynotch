import SwiftUI

/// Placeholder feature: app and notch details, handy while developing.
struct InfoFeatureView: View {
    let geometry: NotchGeometry
    let screenName: String

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            row("Wingmate", "\(AppInfo.version) (\(AppInfo.build))")
            row("Display", screenName)
            row("Notch", geometry.hasPhysicalNotch ? "physical" : "virtual")
            row("Notch size", "\(Int(geometry.notchSize.width)) × \(Int(geometry.notchSize.height)) pt")
        }
        .font(.notch(size: 13))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }
}
