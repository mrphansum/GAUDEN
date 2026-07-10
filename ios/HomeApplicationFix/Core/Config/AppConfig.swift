/**
 AppConfig — base URL API và IDs.

 Giải thích:
 - Đổi `apiBaseURL` thành IP máy Windows chạy backend (cùng Wi‑Fi).
 - Google client IDs lấy từ Google Cloud Console; để trống thì dùng email login + dev Google mock.
 */
import Foundation

enum AppConfig {
    /// ⚠️ Đổi thành IP máy Windows khi test device thật, ví dụ http://192.168.1.10:4000
    static var apiBaseURL: URL {
        if let override = UserDefaults.standard.string(forKey: "apiBaseURL"),
           let url = URL(string: override) {
            return url
        }
        #if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:4000")!
        #else
        // Device: sửa IP này cho khớp máy Windows backend
        return URL(string: "http://192.168.1.10:4000")!
        #endif
    }

    static let bundleId = "com.mrphansum.homeapplicationfix"
    static let appDisplayName = "Home Application Fix"

    /// iOS OAuth client ID (Google Sign-In). Ví dụ: 123-abc.apps.googleusercontent.com
    static let googleIOSClientID = ""
    /// Server / Web client ID — dùng làm serverClientID khi cần
    static let googleServerClientID = ""

    /// Product id Gói 1 — khớp seed backend
    static let module1ProductId = "com.mrphansum.homeapplicationfix.module1"

    /// Debug: cho phép mock IAP khi StoreKit không có product
    static let allowMockIAPInDebug = true
}
