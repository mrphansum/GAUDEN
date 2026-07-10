// Home Application Fix — entry point
// App name: Home Application Fix | Bundle: com.mrphansum.homeapplicationfix

import SwiftUI

@main
struct HomeApplicationFixApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .task {
                    await appState.bootstrap()
                }
        }
    }
}
