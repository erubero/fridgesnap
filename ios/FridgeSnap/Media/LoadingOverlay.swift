import Lottie
import SwiftUI

// Full-screen wait state shown while a scan or generation call is running.
// Plays one of the owner's Lottie loaders on the cream canvas with the
// current status line underneath.
struct LoadingOverlay: View {
    let message: String
    @State private var animation = LoadingAnimation.random()

    var body: some View {
        ZStack {
            Theme.canvas
                .opacity(0.96)
                .ignoresSafeArea()
            VStack(spacing: 8) {
                LottieView(animation: .named(animation.rawValue))
                    .playing(loopMode: .loop)
                    .frame(width: 220, height: 220)
                Text(message)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("Takes a few seconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .transition(.opacity)
        .accessibilityLabel(message)
    }
}
