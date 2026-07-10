# Home Application Fix — Backend

API TypeScript (Express + MongoDB) cho app iOS **Home Application Fix**.

## Yêu cầu (Windows)

1. **Node.js 18+** — https://nodejs.org  
2. **MongoDB Community** — https://www.mongodb.com/try/download/community  
   - Chạy service MongoDB (mặc định `mongodb://127.0.0.1:27017`)  
3. (Tuỳ chọn) **Google Cloud OAuth** client IDs cho đăng nhập Gmail  

## Cài & chạy

```bat
cd backend
copy .env.example .env
:: Sửa .env nếu cần (JWT secrets, Google client IDs)

npm install
npm run seed
npm run dev
```

Server: `http://localhost:4000`  
Health: `http://localhost:4000/health`  

Máy iOS/simulator trên cùng LAN: dùng IP Windows, ví dụ `http://192.168.1.10:4000`.

Build production:

```bat
npm run build
npm start
```

## API chính

| Method | Path | Auth | Mô tả |
|--------|------|------|--------|
| POST | `/api/auth/register` | — | Đăng ký email/password |
| POST | `/api/auth/login` | — | Đăng nhập |
| POST | `/api/auth/google` | — | Đăng ký/nhập Gmail (`idToken`) |
| POST | `/api/auth/refresh` | — | Đổi refresh → access mới (rotate) |
| POST | `/api/auth/logout` | — | Revoke refresh token |
| GET | `/api/modules` | optional | Catalog + categories |
| GET | `/api/modules/:id` | optional | Detail + demo; full nếu owned |
| GET | `/api/modules/:id/content` | required + own | Full content |
| POST | `/api/iap/verify` | required | Verify Non-Consumable IAP |
| GET | `/api/me` | required | Profile |
| GET | `/api/me/purchases` | required | Gói đã mua |

### Ví dụ curl

```bat
curl -X POST http://localhost:4000/api/auth/register -H "Content-Type: application/json" -d "{\"email\":\"a@test.com\",\"password\":\"password123\",\"name\":\"An\"}"

curl http://localhost:4000/api/modules
```

## Bảo mật

- Access JWT ngắn hạn + **refresh token** (hash SHA-256 trong DB, rotation).  
- Password: **bcrypt**.  
- IAP: server-side verify; dev bật `IAP_MOCK_VERIFY=true`.  
- Google: verify `idToken` bằng `google-auth-library` khi đã set `GOOGLE_CLIENT_ID`.  

## Gói 1 (seed)

- Slug: `module-1-home-basics`  
- Product ID: `com.mrphansum.homeapplicationfix.module1`  
- Loại IAP: **Non-Consumable**  

Thêm gói sau: insert document `Module` mới (hoặc mở rộng seed) + tạo product App Store tương ứng.

## Cấu trúc thư mục

```
src/
  config/env.ts          # load & validate .env
  models/                # User, RefreshToken, Module, Purchase
  services/              # token, google, iap
  middleware/            # auth JWT, errors
  routes/                # auth, modules, iap, me
  scripts/seed.ts
  app.ts / index.ts
```

## Google Sign-In (Gmail)

1. Google Cloud Console → OAuth 2.0 Client IDs (iOS + Web).  
2. Đặt vào `.env`:  
   - `GOOGLE_CLIENT_ID` = Web client ID (server verify audience)  
   - `GOOGLE_IOS_CLIENT_ID` = iOS client ID  
3. iOS app dùng cùng iOS client ID trong GoogleSignIn config.  

Khi **chưa** cấu hình client ID, server ở `development` cho phép decode idToken dev (không an toàn — chỉ test local).
