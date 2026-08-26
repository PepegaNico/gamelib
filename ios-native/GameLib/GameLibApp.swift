import SwiftUI

@main
struct GameLibApp: App {
    @State private var auth = AuthViewModel()
    @State private var library = LibraryViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(library)
                .task {
                    auth.restore()
                }
        }
    }
}

/// Mirrors the Flutter app's `_RootScreen`: switches on the auth state
/// machine to pick the right top-level screen.
private struct RootView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        switch auth.status {
        case .unknown:
            ProgressView()
        case .needsApiKey, .needsLogin:
            SteamLoginView()
        case .signedIn:
            LibraryView()
        }
    }
}
