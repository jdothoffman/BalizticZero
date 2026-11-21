import SwiftData
import SwiftUI

@main
struct BalizticZeroApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: LoadProfile.self)
    }
}
