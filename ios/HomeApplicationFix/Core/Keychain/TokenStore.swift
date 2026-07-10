/**
 TokenStore — facade trên Keychain cho access + refresh token.
 */
import Foundation

struct TokenPair: Equatable {
    let accessToken: String
    let refreshToken: String
    let refreshExpiresAt: String?
}

final class TokenStore {
    static let shared = TokenStore()

    func save(tokens: TokenDTO) {
        KeychainStore.set(tokens.accessToken, for: .accessToken)
        KeychainStore.set(tokens.refreshToken, for: .refreshToken)
        if let exp = tokens.refreshExpiresAt {
            KeychainStore.set(exp, for: .refreshExpiresAt)
        }
    }

    func loadTokens() -> TokenPair? {
        guard let access = KeychainStore.get(.accessToken),
              let refresh = KeychainStore.get(.refreshToken) else {
            return nil
        }
        return TokenPair(
            accessToken: access,
            refreshToken: refresh,
            refreshExpiresAt: KeychainStore.get(.refreshExpiresAt)
        )
    }

    func updateAccessToken(_ access: String) {
        KeychainStore.set(access, for: .accessToken)
    }

    func clear() {
        KeychainStore.clearAll()
    }
}
