# Home Application Fix (GAUDEN)

Ứng dụng iOS bán **module / Add-on (DLC)** dạng **Non-Consumable IAP**, kèm backend **Express + TypeScript + MongoDB**.

- **Tên app:** Home Application Fix  
- **Bundle ID:** `com.mrphansum.homeapplicationfix`  
- **Gói 1:** `com.mrphansum.homeapplicationfix.module1`  

## Cấu trúc repo

```
GAUDEN/
  backend/     # API TypeScript — chạy trên Windows
  ios/         # Xcode project Home Application Fix
  README.md
```

## Kiến trúc nhanh

```
┌─────────────────┐     HTTPS/HTTP LAN      ┌──────────────────────┐
│  iOS App        │ ──────────────────────► │  Express (TS)        │
│  SwiftUI        │     JWT + refresh       │  MongoDB             │
│  Keychain tokens│ ◄────────────────────── │  IAP verify          │
│  StoreKit 2     │                         │  Google idToken      │
└─────────────────┘                         └──────────────────────┘
```

### Quyền truy cập nội dung

| Trạng thái | Demo doc/video | Full content | Mua IAP |
|------------|----------------|--------------|---------|
| Guest | Có | Không | Yêu cầu đăng ký/đăng nhập |
| User chưa mua | Có | Không | Có |
| User đã mua | Có | Có | Restore / đã own |

### Bảo mật (đã làm)

- Access JWT ngắn hạn + **refresh token rotate** (hash trong Mongo)  
- Token trên iOS chỉ trong **Keychain**  
- Password **bcrypt**  
- Entitlement **server-side** sau IAP verify  
- Google Gmail: verify `idToken` (production) / dev decode (local)  
- **Không** dùng Biometric  

### Đa ngôn ngữ

- iOS: English + Tiếng Việt (`Localizable.xcstrings`)  
- Dễ thêm locale mới trong String Catalog  

### Mở rộng module

1. Thêm document `Module` (hoặc mở rộng `npm run seed`)  
2. Tạo Non-Consumable product trên App Store cùng `appleProductId`  
3. App catalog lấy dynamic từ `GET /api/modules` — không hardcode UI theo 1 gói  

## Chạy backend trên Windows

Xem chi tiết: [`backend/README.md`](backend/README.md)

```bat
cd backend
copy .env.example .env
npm install
npm run seed
npm run dev
```

## Chạy iOS

Xem chi tiết: [`ios/README.md`](ios/README.md)

1. Mở `ios/HomeApplicationFix.xcodeproj`  
2. Trỏ `AppConfig.apiBaseURL` → IP máy Windows  
3. Run  

## API tóm tắt

- `POST /api/auth/register|login|google|refresh|logout`  
- `GET /api/modules` · `GET /api/modules/:id` · `GET /api/modules/:id/content`  
- `POST /api/iap/verify`  
- `GET /api/me` · `GET /api/me/purchases`  

## Tài liệu học (docs/)

| File | Nội dung |
|------|----------|
| [`docs/LUONG_HOAT_DONG.txt`](docs/LUONG_HOAT_DONG.txt) | Luồng nghiệp vụ / ai được làm gì |
| [`docs/DATA_FLOW.txt`](docs/DATA_FLOW.txt) | JSON, Mongo, Keychain, source of truth |
| [`docs/CALL_CHAIN_HOC_TAP.txt`](docs/CALL_CHAIN_HOC_TAP.txt) | **Call chain**: hàm nào → qua đâu → server (dùng để học trace code) |

## Ghi chú production

1. Đổi JWT secrets, tắt `IAP_MOCK_VERIFY`  
2. Cấu hình Google OAuth client IDs  
3. Verify IAP bằng App Store Server Library / JWS cert chain  
4. HTTPS + reverse proxy (nginx)  
5. App Store Connect products + privacy nutrition labels  
