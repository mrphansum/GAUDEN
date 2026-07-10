/**
 GoogleSignInHelper — Gmail sign-in.

 Giải thích:
 - Nếu AppConfig.googleIOSClientID được set và có SDK GoogleSignIn: dùng production flow.
 - Hiện tại project không bắt buộc SPM GoogleSignIn để build được ngay;
   helper tạo dev idToken JWT (unsigned) khớp backend dev decode.
 - Khi lên production: thêm package GoogleSignIn và thay body getIdToken() bằng GIDSignIn.
 */
import Foundation
import UIKit

enum GoogleSignInHelper {
    enum GError: LocalizedError {
        case cancelled
        case missingClient
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: return L10n.tr("auth.googleCancelled")
            case .missingClient: return L10n.tr("auth.googleMissingConfig")
            case .failed(let m): return m
            }
        }
    }

    @MainActor
    static func getIdToken() async throws -> String {
        // Production path (khi đã cấu hình client ID):
        // Dùng GoogleSignIn SDK — xem README iOS.
        // Ở đây: luôn hỗ trợ dev token để test end-to-end với backend Windows.
        if AppConfig.googleIOSClientID.isEmpty {
            return try await presentDevGoogleForm()
        }
        // Placeholder cho SDK: vẫn dùng dev form nếu chưa link package
        return try await presentDevGoogleForm()
    }

    /// Form dev: nhập Gmail → tạo JWT payload giả (backend development accept)
    @MainActor
    private static func presentDevGoogleForm() async throws -> String {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController else {
            // Fallback không UI
            return makeDevJWT(email: "demo.user@gmail.com", name: "Demo User", sub: "dev-google-1")
        }

        return try await withCheckedThrowingContinuation { cont in
            let alert = UIAlertController(
                title: L10n.tr("auth.googleDevTitle"),
                message: L10n.tr("auth.googleDevMessage"),
                preferredStyle: .alert
            )
            alert.addTextField { tf in
                tf.placeholder = "name@gmail.com"
                tf.keyboardType = .emailAddress
                tf.text = "demo.user@gmail.com"
            }
            alert.addTextField { tf in
                tf.placeholder = L10n.tr("auth.name")
                tf.text = "Demo User"
            }
            alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel) { _ in
                cont.resume(throwing: GError.cancelled)
            })
            alert.addAction(UIAlertAction(title: L10n.tr("auth.continue"), style: .default) { _ in
                let email = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let email, !email.isEmpty else {
                    cont.resume(throwing: GError.failed("Email required"))
                    return
                }
                let token = makeDevJWT(
                    email: email,
                    name: name?.isEmpty == false ? name! : email.split(separator: "@").first.map(String.init) ?? "User",
                    sub: "dev-\(email.lowercased())"
                )
                cont.resume(returning: token)
            })
            root.present(alert, animated: true)
        }
    }

    /// JWT-shaped string: header.payload.sig — backend dev chỉ đọc payload
    static func makeDevJWT(email: String, name: String, sub: String) -> String {
        func b64(_ obj: [String: Any]) -> String {
            let data = try! JSONSerialization.data(withJSONObject: obj)
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let header = b64(["alg": "none", "typ": "JWT"])
        let payload = b64([
            "sub": sub,
            "email": email,
            "name": name,
            "email_verified": true,
            "iss": "https://accounts.google.com",
            "aud": "dev"
        ])
        return "\(header).\(payload).dev"
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? {
        windows.first { $0.isKeyWindow } ?? windows.first
    }
}
