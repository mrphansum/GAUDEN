import Foundation

final class ModuleService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func fetchModules(category: String? = nil) async throws -> ModulesResponse {
        var path = "/api/modules"
        if let category, !category.isEmpty {
            let encoded = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category
            path += "?category=\(encoded)"
        }
        // Gửi token nếu có để nhận owned flags
        let hasToken = TokenStore.shared.loadTokens() != nil
        return try await api.request(path: path, authorized: hasToken)
    }

    func fetchDetail(idOrSlug: String) async throws -> ModuleDetailDTO {
        let hasToken = TokenStore.shared.loadTokens() != nil
        let res: ModuleDetailResponse = try await api.request(
            path: "/api/modules/\(idOrSlug)",
            authorized: hasToken
        )
        return res.module
    }

    func fetchFullContent(idOrSlug: String) async throws -> FullContentResponse {
        try await api.request(
            path: "/api/modules/\(idOrSlug)/content",
            authorized: true
        )
    }

    func fetchPurchases() async throws -> [PurchaseDTO] {
        let res: PurchasesResponse = try await api.request(
            path: "/api/me/purchases",
            authorized: true
        )
        return res.purchases
    }
}
