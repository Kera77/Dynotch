import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Dynotch")
                .font(.largeTitle.bold())
            Text("Version \(AppInfo.version) (\(AppInfo.build))")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(minWidth: 360, minHeight: 240)
    }
}

#Preview {
    ContentView()
}
