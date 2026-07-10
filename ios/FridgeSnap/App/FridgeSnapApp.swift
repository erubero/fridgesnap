import SwiftData
import SwiftUI

@main
struct FridgeSnapApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            RootTabView(services: services)
        }
        .modelContainer(for: LocalScan.self)
    }
}
