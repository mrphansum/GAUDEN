import Foundation

// MARK: - Auth

struct UserDTO: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let name: String
    let avatarUrl: String?
    let providers: [String]?
}

struct TokenDTO: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let refreshExpiresAt: String?
    let tokenType: String?
}

struct AuthResponse: Codable {
    let user: UserDTO
    let tokens: TokenDTO
}

struct MeResponse: Codable {
    let user: UserDTO
}

// MARK: - Modules

struct ContentItemDTO: Codable, Identifiable, Equatable {
    var id: String { "\(type)-\(title)-\(url)" }
    let type: String // document | video
    let title: String
    let url: String
    let description: String?
    let durationSeconds: Int?
}

struct ModuleSummary: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let slug: String
    let title: String
    let subtitle: String?
    let description: String
    let category: String
    let appleProductId: String
    let coverImageUrl: String?
    let demoCount: Int?
    let owned: Bool
    let sortOrder: Int?
}

struct ModulesResponse: Codable {
    let modules: [ModuleSummary]
    let categories: [String]
}

struct ModuleDetailDTO: Codable {
    let id: String
    let slug: String
    let title: String
    let subtitle: String?
    let description: String
    let category: String
    let appleProductId: String
    let coverImageUrl: String?
    let owned: Bool
    let demoContent: [ContentItemDTO]
    let fullContent: [ContentItemDTO]?
    let requiresPurchase: Bool?
}

struct ModuleDetailResponse: Codable {
    let module: ModuleDetailDTO
}

struct FullContentResponse: Codable {
    let moduleId: String
    let title: String
    let fullContent: [ContentItemDTO]
}

// MARK: - IAP / Purchases

struct IAPVerifyRequest: Codable {
    let productId: String
    let transactionId: String
    let originalTransactionId: String?
    let signedTransaction: String?
}

struct IAPVerifyResponse: Codable {
    let ok: Bool
    let alreadyOwned: Bool
    let purchase: PurchaseDTO?
    let module: PurchaseModuleRef?
}

struct PurchaseDTO: Codable, Identifiable {
    let id: String
    let moduleId: String?
    let appleProductId: String
    let transactionId: String
    let purchasedAt: String?
    let source: String?
    let module: PurchaseModuleRef?
}

struct PurchaseModuleRef: Codable {
    let id: String
    let slug: String?
    let title: String
    let subtitle: String?
    let category: String?
    let coverImageUrl: String?
}

struct PurchasesResponse: Codable {
    let purchases: [PurchaseDTO]
}

// MARK: - Errors

struct APIErrorBody: Codable {
    let error: String?
    let message: String?
}

enum APIError: LocalizedError {
    case invalidURL
    case http(Int, String?)
    case decoding
    case unauthorized
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .http(let code, let msg): return msg ?? "HTTP \(code)"
        case .decoding: return "Failed to decode response"
        case .unauthorized: return "Unauthorized"
        case .underlying(let e): return e.localizedDescription
        }
    }
}
