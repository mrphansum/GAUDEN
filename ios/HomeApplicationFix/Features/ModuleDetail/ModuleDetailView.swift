import SwiftUI
import AVKit

struct ModuleDetailView: View {
    @EnvironmentObject private var appState: AppState
    let moduleId: String

    @State private var detail: ModuleDetailDTO?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBuying = false
    @State private var storePrice: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(L10n.tr("common.loading"))
            } else if let errorMessage, detail == nil {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(L10n.tr("catalog.errorTitle"))
                        .font(.headline)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let detail {
                content(detail)
            }
        }
        .navigationTitle(detail?.title ?? L10n.tr("module.detail"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func content(_ detail: ModuleDetailDTO) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(detail)
                Text(detail.description)
                    .font(.body)
                    .foregroundStyle(.primary)

                sectionTitle(L10n.tr("module.demo"))
                ContentListView(items: detail.demoContent, emptyText: L10n.tr("module.noDemo"))

                if detail.owned, let full = detail.fullContent {
                    sectionTitle(L10n.tr("module.full"))
                    ContentListView(items: full, emptyText: L10n.tr("module.noFull"))
                } else {
                    purchaseCard(detail)
                }
            }
            .padding(20)
        }
    }

    private func header(_ detail: ModuleDetailDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(detail.category)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12), in: Capsule())
                if detail.owned {
                    Label(L10n.tr("catalog.owned"), systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            if let subtitle = detail.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
            .padding(.top, 4)
    }

    private func purchaseCard(_ detail: ModuleDetailDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.tr("module.unlock"))
            Text(L10n.tr("module.unlockHint"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Task { await buy(detail) }
            } label: {
                HStack {
                    if isBuying {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "cart.fill")
                        Text(buyButtonTitle(detail))
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBuying)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .task {
            if let product = try? await appState.iapService.product(for: detail.appleProductId) {
                storePrice = product.displayPrice
            }
        }
    }

    private func buyButtonTitle(_ detail: ModuleDetailDTO) -> String {
        if let storePrice {
            return L10n.tr("module.buyPrice", storePrice)
        }
        return L10n.tr("module.buy")
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            detail = try await appState.moduleService.fetchDetail(idOrSlug: moduleId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buy(_ detail: ModuleDetailDTO) async {
        // Bắt buộc đăng ký/đăng nhập trước khi mua
        guard appState.isLoggedIn else {
            appState.requireAuth(forPurchase: ModuleSummary(
                id: detail.id,
                slug: detail.slug,
                title: detail.title,
                subtitle: detail.subtitle,
                description: detail.description,
                category: detail.category,
                appleProductId: detail.appleProductId,
                coverImageUrl: detail.coverImageUrl,
                demoCount: detail.demoContent.count,
                owned: false,
                sortOrder: nil
            ))
            return
        }

        isBuying = true
        defer { isBuying = false }
        do {
            _ = try await appState.iapService.purchase(productId: detail.appleProductId)
            appState.showToast(L10n.tr("iap.success"))
            await load()
        } catch {
            appState.showToast(error.localizedDescription)
        }
    }
}

struct ContentListView: View {
    let items: [ContentItemDTO]
    let emptyText: String

    var body: some View {
        if items.isEmpty {
            Text(emptyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 10) {
                ForEach(items) { item in
                    NavigationLink {
                        ContentPlayerView(item: item)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.type == "video" ? "play.rectangle.fill" : "doc.text.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if let desc = item.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ContentPlayerView: View {
    let item: ContentItemDTO

    var body: some View {
        Group {
            if item.type == "video", let url = URL(string: item.url) {
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea(edges: .bottom)
            } else if let url = URL(string: item.url) {
                WebContentView(url: url)
            } else {
                Text(L10n.tr("module.invalidURL"))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WebContentView: View {
    let url: URL
    var body: some View {
        // Tránh phụ thuộc WebKit import issues — Link + Safari fallback đơn giản
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text(L10n.tr("module.openDocument"))
                .font(.headline)
            Link(destination: url) {
                Text(url.absoluteString)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .padding()
    }
}
