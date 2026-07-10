/**
 AuthView — Đăng nhập / Đăng ký email + Gmail (Google).

 Giải thích:
 - Mua hàng bắt buộc auth; guest vẫn xem demo.
 - Google: nếu đã cấu hình client ID dùng SDK; không thì nút dev tạo idToken giả (backend dev decode).
 */
import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .login
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Mode { case login, register }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    modePicker
                    fields
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    primaryButton
                    googleButton
                    Text(L10n.tr("auth.privacyNote"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .navigationTitle(L10n.tr("auth.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.close")) { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "house.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
            Text(AppConfig.appDisplayName)
                .font(.title2.bold())
            Text(L10n.tr("auth.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var modePicker: some View {
        Picker("", selection: $mode) {
            Text(L10n.tr("auth.login")).tag(Mode.login)
            Text(L10n.tr("auth.register")).tag(Mode.register)
        }
        .pickerStyle(.segmented)
    }

    private var fields: some View {
        VStack(spacing: 12) {
            if mode == .register {
                TextField(L10n.tr("auth.name"), text: $name)
                    .textContentType(.name)
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            TextField(L10n.tr("auth.email"), text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            SecureField(L10n.tr("auth.password"), text: $password)
                .textContentType(mode == .register ? .newPassword : .password)
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var primaryButton: some View {
        Button {
            Task { await submit() }
        } label: {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(mode == .login ? L10n.tr("auth.login") : L10n.tr("auth.register"))
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading || email.isEmpty || password.count < 8 || (mode == .register && name.isEmpty))
    }

    private var googleButton: some View {
        Button {
            Task { await signInWithGoogle() }
        } label: {
            HStack {
                Image(systemName: "g.circle.fill")
                Text(L10n.tr("auth.google"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .disabled(isLoading)
    }

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let res: AuthResponse
            if mode == .login {
                res = try await appState.authService.login(email: email, password: password)
            } else {
                res = try await appState.authService.register(name: name, email: email, password: password)
            }
            appState.applyAuth(res)
            appState.showToast(L10n.tr("auth.success"))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signInWithGoogle() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let idToken = try await GoogleSignInHelper.getIdToken()
            let res = try await appState.authService.loginWithGoogle(idToken: idToken)
            appState.applyAuth(res)
            appState.showToast(L10n.tr("auth.success"))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
