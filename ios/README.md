# Home Application Fix — iOS

SwiftUI app (iOS 16+) cho **Home Application Fix**.

## Mở project

1. Mở `HomeApplicationFix.xcodeproj` bằng Xcode 15+.
2. Chọn Team signing (Signing & Capabilities).
3. Bundle ID: `com.mrphansum.homeapplicationfix`
4. Chạy Simulator hoặc device.

## Kết nối backend (máy Windows)

1. Chạy API trên Windows: `http://<IP-Windows>:4000`
2. Sửa `AppConfig.apiBaseURL` trong  
   `HomeApplicationFix/Core/Config/AppConfig.swift`  
   - Simulator cùng Mac host backend: `http://127.0.0.1:4000`  
   - iPhone thật: `http://192.168.x.x:4000` (IP LAN Windows)  
3. Hoặc set runtime:  
   `UserDefaults.standard.set("http://192.168.1.10:4000", forKey: "apiBaseURL")`

`Info.plist` đã bật ATS local networking cho HTTP dev.

## Tính năng

| Feature | Ghi chú |
|---------|---------|
| Catalog + categories | `GET /api/modules` |
| Demo free (doc/video) | Không cần login |
| Mua Non-Consumable | Bắt buộc login → StoreKit 2 → `/api/iap/verify` |
| Keychain | Access + refresh token |
| Refresh token | Tự động khi 401 |
| Gmail | Nút “Tiếp tục với Gmail” (dev form + JWT giả; production gắn GoogleSignIn SDK) |
| Profile | Gói đã mua, restore, logout |
| i18n | VI + EN (`Localizable.xcstrings`) |

## IAP

- Product ID Gói 1: `com.mrphansum.homeapplicationfix.module1`
- Loại: **Non-Consumable**
- Debug: nếu App Store không trả product, app mock purchase (backend `IAP_MOCK_VERIFY=true`)

App Store Connect (khi lên store):

1. Tạo app + In-App Purchase Non-Consumable cùng product id.
2. Sandbox tester.
3. Tắt mock trên backend (`IAP_MOCK_VERIFY=false`) và harden verify JWS.

## Google / Gmail production

1. Google Cloud → OAuth iOS client (bundle id khớp).
2. Set `AppConfig.googleIOSClientID` + backend `GOOGLE_CLIENT_ID` / `GOOGLE_IOS_CLIENT_ID`.
3. Thêm SPM: [GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS) và thay `GoogleSignInHelper.getIdToken()` bằng `GIDSignIn`.

Hiện tại helper dùng form dev để test full flow với backend Windows mà không cần Google Console ngay.

## Cấu trúc

```
HomeApplicationFix/
  App/                 # App entry, RootView, AppState
  Core/
    Config/            # API base URL, product ids
    Keychain/          # KeychainStore + TokenStore
    Networking/        # APIClient + auto refresh
    Models/            # DTOs
    Services/          # Auth, Module, IAP
    Localization/
  Features/
    Auth/              # Login, Register, Gmail
    Catalog/
    ModuleDetail/      # Demo + Buy + Content
    Profile/
  Resources/           # Assets, Info.plist, strings
```

## Flow mua hàng (tóm tắt)

1. Guest mở Gói 1 → xem demo.  
2. Bấm **Mua** → sheet đăng ký/đăng nhập (email hoặc Gmail).  
3. StoreKit purchase (hoặc mock DEBUG).  
4. App gửi transaction lên server → entitlement.  
5. Profile hiển thị gói đã mua; full content mở khoá.
