import SwiftUI

/// Tab chính: Khám phá (catalog) + Hồ sơ. UI tối giản, rõ CTA.
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isBootstrapping {
                ProgressView(L10n.tr("common.loading"))
            } else {
                TabView {
                    CatalogView()
                        .tabItem {
                            Label(L10n.tr("tab.explore"), systemImage: "square.grid.2x2.fill")
                        }
                    ProfileView()
                        .tabItem {
                            Label(L10n.tr("tab.profile"), systemImage: "person.crop.circle")
                        }
                }
            }
        }
        .sheet(isPresented: $appState.authPresented) {
            AuthView()
                .environmentObject(appState)
        }
        .overlay(alignment: .bottom) {
            if let toast = appState.toastMessage {
                Text(toast)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
                    .onAppear {
                        Task {
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            if appState.toastMessage == toast {
                                appState.toastMessage = nil
                            }
                        }
                    }
            }
        }
    }
}
