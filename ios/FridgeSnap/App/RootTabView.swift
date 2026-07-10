import SwiftUI

// Tab bar per spec section 6: Scan (primary), My Recipes, Community, Settings.
// My Recipes lands in M3, Community in M5, Settings in M6.
struct RootTabView: View {
    let services: AppServices
    @State private var scanFlow: ScanFlowModel
    @State private var checkedSession = false

    init(services: AppServices) {
        self.services = services
        _scanFlow = State(initialValue: ScanFlowModel(services: services))
    }

    var body: some View {
        Group {
            if !checkedSession {
                ProgressView()
                    .task {
                        await services.auth.restoreSession()
                        checkedSession = true
                    }
            } else if !services.auth.isSignedIn {
                SignInView(auth: services.auth)
            } else {
                tabs
            }
        }
    }

    private var tabs: some View {
        TabView {
            ScanHomeView(model: scanFlow)
                .tabItem { Label("Scan", systemImage: "camera.fill") }

            PlaceholderScreen(
                title: "My Recipes",
                systemImage: "book.fill",
                message: "Saved and cooked recipes land in the next build."
            )
            .tabItem { Label("My Recipes", systemImage: "book.fill") }

            PlaceholderScreen(
                title: "Community",
                systemImage: "person.2.fill",
                message: "Recipes from other lazy people will live here."
            )
            .tabItem { Label("Community", systemImage: "person.2.fill") }

            PlaceholderScreen(
                title: "Settings",
                systemImage: "gearshape.fill",
                message: "Preferences and account will live here."
            )
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
                .navigationTitle(title)
        }
    }
}
