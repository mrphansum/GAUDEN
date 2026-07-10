/**
 IAPService — StoreKit 2 Non-Consumable + verify server.

 Giải thích:
 - product(for:) load metadata/giá từ App Store.
 - purchase: StoreKit → lấy transaction → POST /api/iap/verify.
 - Debug mock: khi product không có trên Store, tạo transactionId giả (IAP_MOCK_VERIFY backend).
 */
import Foundation
import StoreKit
import Combine

@MainActor
final class IAPService: ObservableObject {
    private let api: APIClient
    @Published var isPurchasing = false
    @Published var lastError: String?

    init(api: APIClient) {
        self.api = api
    }

    func product(for productId: String) async throws -> Product? {
        let products = try await Product.products(for: [productId])
        return products.first
    }

    /// Mua Non-Consumable rồi verify với backend (source of truth entitlement)
    func purchase(productId: String) async throws -> IAPVerifyResponse {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        if let product = try await product(for: productId) {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                // jwsRepresentation: chuỗi JWS gửi backend verify (production)
                let jws = verification.jwsRepresentation
                let response = try await verifyOnServer(
                    productId: productId,
                    transactionId: String(transaction.id),
                    originalTransactionId: String(transaction.originalID),
                    signedTransaction: jws
                )
                await transaction.finish()
                return response
            case .userCancelled:
                throw APIError.http(0, L10n.tr("iap.cancelled"))
            case .pending:
                throw APIError.http(0, L10n.tr("iap.pending"))
            @unknown default:
                throw APIError.http(0, L10n.tr("iap.unknown"))
            }
        }

        #if DEBUG
        if AppConfig.allowMockIAPInDebug {
            return try await mockPurchase(productId: productId)
        }
        #endif
        throw APIError.http(0, L10n.tr("iap.productMissing"))
    }

    func restoreAndSync(productIds: [String]) async throws {
        try await AppStore.sync()
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            let pid = transaction.productID
            guard productIds.contains(pid) else { continue }
            let jws = result.jwsRepresentation
            _ = try? await verifyOnServer(
                productId: pid,
                transactionId: String(transaction.id),
                originalTransactionId: String(transaction.originalID),
                signedTransaction: jws
            )
        }
    }

    private func verifyOnServer(
        productId: String,
        transactionId: String,
        originalTransactionId: String?,
        signedTransaction: String?
    ) async throws -> IAPVerifyResponse {
        try await api.request(
            path: "/api/iap/verify",
            method: "POST",
            body: IAPVerifyRequest(
                productId: productId,
                transactionId: transactionId,
                originalTransactionId: originalTransactionId,
                signedTransaction: signedTransaction
            ),
            authorized: true
        )
    }

    #if DEBUG
    private func mockPurchase(productId: String) async throws -> IAPVerifyResponse {
        let tx = "mock-\(productId)-\(UUID().uuidString)"
        return try await verifyOnServer(
            productId: productId,
            transactionId: tx,
            originalTransactionId: tx,
            signedTransaction: nil
        )
    }
    #endif

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
