/**
 APIClient — HTTP layer + tự động refresh token khi 401.

 Giải thích:
 - tokenProvider: đọc access token từ Keychain.
 - refreshHandler: gọi /auth/refresh một lần, retry request gốc.
 - Dùng actor-like serial queue đơn giản cho refresh để tránh double-refresh.
 */
import Foundation

final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    private let session: URLSession
    private let refreshLock = NSLock()
    private var isRefreshing = false

    var tokenProvider: (() -> TokenPair?)?
    var refreshHandler: (() async throws -> Void)?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        authorized: Bool = false,
        retryOnUnauthorized: Bool = true
    ) async throws -> T {
        let data = try await requestData(
            path: path,
            method: method,
            body: body,
            authorized: authorized,
            retryOnUnauthorized: retryOnUnauthorized
        )
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    func requestData(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        authorized: Bool = false,
        retryOnUnauthorized: Bool = true
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: AppConfig.apiBaseURL) else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authorized, let token = tokenProvider?()?.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.http(-1, "No HTTP response")
        }

        if http.statusCode == 401, authorized, retryOnUnauthorized {
            try await refreshIfNeeded()
            return try await requestData(
                path: path,
                method: method,
                body: body,
                authorized: authorized,
                retryOnUnauthorized: false
            )
        }

        guard (200..<300).contains(http.statusCode) else {
            let msg = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            if http.statusCode == 401 { throw APIError.unauthorized }
            throw APIError.http(http.statusCode, msg?.message ?? msg?.error)
        }
        return data
    }

    private func refreshIfNeeded() async throws {
        // Chỉ một refresh tại một thời điểm
        refreshLock.lock()
        if isRefreshing {
            refreshLock.unlock()
            try await Task.sleep(nanoseconds: 350_000_000)
            return
        }
        isRefreshing = true
        refreshLock.unlock()

        defer {
            refreshLock.lock()
            isRefreshing = false
            refreshLock.unlock()
        }

        guard let handler = refreshHandler else {
            throw APIError.unauthorized
        }
        try await handler()
    }
}

/// Type-erase Encodable for generic body encoding
private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        self.encodeFunc = { encoder in
            try wrapped.encode(to: encoder)
        }
    }
    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
