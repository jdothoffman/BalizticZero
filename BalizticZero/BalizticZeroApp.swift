import SwiftData
import SwiftUI

@main
struct BalizticZeroApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .modelContainer(for: LoadProfile.self)
    }
}
