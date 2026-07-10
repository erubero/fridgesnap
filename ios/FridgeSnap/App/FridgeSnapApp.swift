import SwiftData
import SwiftUI

@main
struct FridgeSnapApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            RootTabView(services: services)
                .tint(Theme.green)
        }
        .modelContainer(for: [LocalScan.self, SavedRecipe.self])
    }
}
