import SwiftUI
import Combine

struct CatalogView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = CatalogViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.modules.isEmpty {
                    ProgressView(L10n.tr("common.loading"))
                } else if let error = vm.errorMessage, vm.modules.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(L10n.tr("catalog.errorTitle"))
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button(L10n.tr("common.retry")) {
                            Task { await vm.load(appState: appState) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    listContent
                }
            }
            .navigationTitle(AppConfig.appDisplayName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.load(appState: appState) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await vm.load(appState: appState) }
            .refreshable { await vm.load(appState: appState) }
        }
    }

    private var listContent: some View {
        List {
            if !vm.categories.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip(nil)
                            ForEach(vm.categories, id: \.self) { cat in
                                categoryChip(cat)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            Section {
                ForEach(vm.filteredModules) { module in
                    NavigationLink(value: module) {
                        ModuleRow(module: module)
                    }
                }
            } header: {
                Text(L10n.tr("catalog.modules"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: ModuleSummary.self) { module in
            ModuleDetailView(moduleId: module.id)
        }
    }

    private func categoryChip(_ category: String?) -> some View {
        let selected = vm.selectedCategory == category
        return Button {
            vm.selectedCategory = category
        } label: {
            Text(category ?? L10n.tr("catalog.all"))
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ModuleRow: View {
    let module: ModuleSummary

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.12))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(.blue)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(module.title)
                    .font(.headline)
                    .lineLimit(2)
                if let subtitle = module.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Text(module.category)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                    if module.owned {
                        Label(L10n.tr("catalog.owned"), systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else {
                        Text(L10n.tr("catalog.demoAvailable"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var modules: [ModuleSummary] = []
    @Published var categories: [String] = []
    @Published var selectedCategory: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    var filteredModules: [ModuleSummary] {
        guard let selectedCategory else { return modules }
        return modules.filter { $0.category == selectedCategory }
    }

    func load(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res = try await appState.moduleService.fetchModules()
            modules = res.modules
            categories = res.categories
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
