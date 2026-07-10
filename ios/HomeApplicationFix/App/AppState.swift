/**
 AppState — single source of UI session state.

 Giải thích:
 - Giữ user hiện tại, trạng thái auth, và trigger refresh catalog sau mua.
 - Token thật sự nằm trong Keychain (TokenStore), không lưu UserDefaults.
 */
import Foundation
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var user: UserDTO?
    @Published var isBootstrapping = true
    @Published var authPresented = false
    /// Sau khi login thành công để tiếp tục mua module nào
    @Published var pendingPurchaseModule: ModuleSummary?
    @Published var toastMessage: String?

    let api: APIClient
    let tokenStore: TokenStore
    let authService: AuthService
    let moduleService: ModuleService
    let iapService: IAPService

    init(
        api: APIClient = .shared,
        tokenStore: TokenStore = .shared
    ) {
        self.api = api
        self.tokenStore = tokenStore
        let auth = AuthService(api: api, tokenStore: tokenStore)
        self.authService = auth
        self.moduleService = ModuleService(api: api)
        self.iapService = IAPService(api: api)
        // Token chỉ lưu Keychain — không UserDefaults
        api.tokenProvider = { tokenStore.loadTokens() }
        // Refresh rotate: access hết hạn → /auth/refresh → lưu token mới
        api.refreshHandler = {
            try await auth.refreshTokens()
        }
    }

    var isLoggedIn: Bool { user != nil && tokenStore.loadTokens() != nil }

    func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }
        guard tokenStore.loadTokens() != nil else {
            user = nil
            return
        }
        do {
            user = try await authService.fetchMe()
        } catch {
            // Access hết hạn: thử refresh; fail → clear session
            do {
                try await authService.refreshTokens()
                user = try await authService.fetchMe()
            } catch {
                tokenStore.clear()
                user = nil
            }
        }
    }

    func applyAuth(_ response: AuthResponse) {
        tokenStore.save(tokens: response.tokens)
        user = response.user
        authPresented = false
    }

    func logout() async {
        await authService.logout()
        user = nil
        pendingPurchaseModule = nil
    }

    func requireAuth(forPurchase module: ModuleSummary? = nil) {
        pendingPurchaseModule = module
        authPresented = true
    }

    func showToast(_ message: String) {
        toastMessage = message
    }
}
