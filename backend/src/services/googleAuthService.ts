/**
 * googleAuthService — Xác thực đăng nhập/đăng ký bằng Gmail (Google Sign-In).
 *
 * Giải thích:
 * - Client iOS lấy idToken từ Google SDK → gửi lên POST /auth/google.
 * - Server verify idToken với google-auth-library (chống fake token).
 * - Audience phải khớp GOOGLE_CLIENT_ID hoặc GOOGLE_IOS_CLIENT_ID.
 * - User mới: tạo account providers=["google"]. User cũ: link googleId nếu trùng email.
 */
import { OAuth2Client } from "google-auth-library";
import { env } from "../config/env";
import { User, IUser } from "../models/User";

const client = new OAuth2Client();

export interface GoogleProfile {
  googleId: string;
  email: string;
  name: string;
  avatarUrl?: string;
  emailVerified: boolean;
}

export async function verifyGoogleIdToken(idToken: string): Promise<GoogleProfile> {
  const audiences = [env.GOOGLE_CLIENT_ID, env.GOOGLE_IOS_CLIENT_ID].filter(Boolean);

  if (audiences.length === 0) {
    // Dev fallback: decode JWT payload without signature (CHỈ khi chưa cấu hình Google)
    // Production PHẢI set GOOGLE_CLIENT_ID.
    if (env.NODE_ENV === "production") {
      throw new Error("GOOGLE_CLIENT_ID is not configured");
    }
    console.warn(
      "[googleAuth] GOOGLE_CLIENT_ID missing — using insecure dev decode. Do not use in production."
    );
    return decodeIdTokenUnsafeDev(idToken);
  }

  const ticket = await client.verifyIdToken({
    idToken,
    audience: audiences,
  });
  const payload = ticket.getPayload();
  if (!payload?.sub || !payload.email) {
    throw new Error("Invalid Google token payload");
  }

  return {
    googleId: payload.sub,
    email: payload.email,
    name: payload.name || payload.email.split("@")[0],
    avatarUrl: payload.picture,
    emailVerified: Boolean(payload.email_verified),
  };
}

/** Dev-only: parse JWT payload without verify — cho test local khi chưa có Google client. */
function decodeIdTokenUnsafeDev(idToken: string): GoogleProfile {
  const parts = idToken.split(".");
  if (parts.length < 2) {
    throw new Error("Invalid idToken format");
  }
  const json = Buffer.from(parts[1], "base64url").toString("utf8");
  const payload = JSON.parse(json) as {
    sub?: string;
    email?: string;
    name?: string;
    picture?: string;
    email_verified?: boolean;
  };
  if (!payload.sub || !payload.email) {
    throw new Error("Dev Google token missing sub/email");
  }
  return {
    googleId: payload.sub,
    email: payload.email,
    name: payload.name || payload.email.split("@")[0],
    avatarUrl: payload.picture,
    emailVerified: Boolean(payload.email_verified),
  };
}

/**
 * Tìm hoặc tạo user từ profile Google.
 * Nếu email đã tồn tại (đăng ký local trước): gắn googleId + thêm provider google.
 */
export async function findOrCreateGoogleUser(profile: GoogleProfile): Promise<IUser> {
  let user = await User.findOne({
    $or: [{ googleId: profile.googleId }, { email: profile.email.toLowerCase() }],
  });

  if (!user) {
    user = await User.create({
      email: profile.email.toLowerCase(),
      name: profile.name,
      googleId: profile.googleId,
      avatarUrl: profile.avatarUrl,
      providers: ["google"],
    });
    return user;
  }

  let dirty = false;
  if (!user.googleId) {
    user.googleId = profile.googleId;
    dirty = true;
  }
  if (!user.providers.includes("google")) {
    user.providers.push("google");
    dirty = true;
  }
  if (profile.avatarUrl && user.avatarUrl !== profile.avatarUrl) {
    user.avatarUrl = profile.avatarUrl;
    dirty = true;
  }
  if (dirty) {
    await user.save();
  }
  return user;
}
