/**
 AuthService — register/login/Google/refresh/logout.
 */
import Foundation

final class AuthService {
    private let api: APIClient
    private let tokenStore: TokenStore

    init(api: APIClient, tokenStore: TokenStore) {
        self.api = api
        self.tokenStore = tokenStore
    }

    struct RegisterBody: Encodable {
        let email: String
        let password: String
        let name: String
    }

    struct LoginBody: Encodable {
        let email: String
        let password: String
    }

    struct GoogleBody: Encodable {
        let idToken: String
    }

    struct RefreshBody: Encodable {
        let refreshToken: String
    }

    func register(name: String, email: String, password: String) async throws -> AuthResponse {
        try await api.request(
            path: "/api/auth/register",
            method: "POST",
            body: RegisterBody(email: email, password: password, name: name)
        )
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await api.request(
            path: "/api/auth/login",
            method: "POST",
            body: LoginBody(email: email, password: password)
        )
    }

    /// Đăng nhập/đăng ký Gmail qua Google idToken
    func loginWithGoogle(idToken: String) async throws -> AuthResponse {
        try await api.request(
            path: "/api/auth/google",
            method: "POST",
            body: GoogleBody(idToken: idToken)
        )
    }

    func fetchMe() async throws -> UserDTO {
        let res: MeResponse = try await api.request(path: "/api/me", authorized: true)
        return res.user
    }

    func refreshTokens() async throws {
        guard let refresh = tokenStore.loadTokens()?.refreshToken else {
            throw APIError.unauthorized
        }
        let res: AuthResponse = try await api.request(
            path: "/api/auth/refresh",
            method: "POST",
            body: RefreshBody(refreshToken: refresh),
            authorized: false,
            retryOnUnauthorized: false
        )
        tokenStore.save(tokens: res.tokens)
    }

    func logout() async {
        let refresh = tokenStore.loadTokens()?.refreshToken
        if let refresh {
            struct Body: Encodable { let refreshToken: String }
            _ = try? await api.requestData(
                path: "/api/auth/logout",
                method: "POST",
                body: Body(refreshToken: refresh)
            )
        }
        tokenStore.clear()
    }
}
