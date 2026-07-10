import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var purchases: [PurchaseDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if appState.isLoggedIn, let user = appState.user {
                    Section {
                        HStack(spacing: 14) {
                            avatar(user)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let providers = user.providers, !providers.isEmpty {
                                    Text(providers.joined(separator: " · "))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    Section(L10n.tr("profile.purchases")) {
                        if isLoading {
                            ProgressView()
                        } else if purchases.isEmpty {
                            Text(L10n.tr("profile.noPurchases"))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(purchases) { p in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.module?.title ?? p.appleProductId)
                                        .font(.subheadline.weight(.semibold))
                                    if let cat = p.module?.category {
                                        Text(cat)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let date = p.purchasedAt {
                                        Text(date)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    Section {
                        Button {
                            Task { await restore() }
                        } label: {
                            Label(L10n.tr("profile.restore"), systemImage: "arrow.clockwise.circle")
                        }
                        Button(role: .destructive) {
                            Task {
                                await appState.logout()
                                purchases = []
                            }
                        } label: {
                            Label(L10n.tr("profile.logout"), systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.tr("profile.guestTitle"))
                                .font(.headline)
                            Text(L10n.tr("profile.guestBody"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button {
                                appState.authPresented = true
                            } label: {
                                Text(L10n.tr("auth.login"))
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section(L10n.tr("profile.about")) {
                    LabeledContent(L10n.tr("profile.appName"), value: AppConfig.appDisplayName)
                    LabeledContent("API", value: AppConfig.apiBaseURL.absoluteString)
                        .font(.caption)
                }
            }
            .navigationTitle(L10n.tr("tab.profile"))
            .task { await loadPurchases() }
            .refreshable { await loadPurchases() }
            .onChange(of: appState.isLoggedIn) { loggedIn in
                if loggedIn {
                    Task { await loadPurchases() }
                } else {
                    purchases = []
                }
            }
        }
    }

    private func avatar(_ user: UserDTO) -> some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 56, height: 56)
            Text(String(user.name.prefix(1)).uppercased())
                .font(.title2.bold())
                .foregroundStyle(.blue)
        }
    }

    private func loadPurchases() async {
        guard appState.isLoggedIn else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            purchases = try await appState.moduleService.fetchPurchases()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        do {
            let modules = try await appState.moduleService.fetchModules()
            let ids = modules.modules.map(\.appleProductId)
            try await appState.iapService.restoreAndSync(productIds: ids)
            await loadPurchases()
            appState.showToast(L10n.tr("profile.restoreDone"))
        } catch {
            appState.showToast(error.localizedDescription)
        }
    }
}
