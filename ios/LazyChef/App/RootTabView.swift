import SwiftUI

/// Tab bar per spec section 6: Scan (primary), My Recipes, Community, Settings.
/// The tab contents are placeholders until their milestones land
/// (M2 scan flow, M3 My Recipes, M5 community, M6 settings).
struct RootTabView: View {
    var body: some View {
        TabView {
            PlaceholderScreen(
                title: "Scan",
                systemImage: "camera.fill",
                message: "Point your camera at the fridge. Coming in the next build."
            )
            .tabItem { Label("Scan", systemImage: "camera.fill") }

            PlaceholderScreen(
                title: "My Recipes",
                systemImage: "book.fill",
                message: "Saved and cooked recipes will live here."
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

#Preview {
    RootTabView()
}
