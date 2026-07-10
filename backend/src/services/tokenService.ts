/**
 * tokenService — Access JWT + Refresh token (hash + rotate).
 *
 * Giải thích:
 * - Access token: JWT ngắn hạn, client gửi kèm Authorization: Bearer ...
 * - Refresh token: chuỗi random opaque, chỉ server biết hash; lưu Keychain trên iOS.
 * - Rotate on refresh: giảm rủi ro nếu refresh token bị lộ.
 */
import crypto from "crypto";
import jwt from "jsonwebtoken";
import { Types } from "mongoose";
import { env } from "../config/env";
import { RefreshToken } from "../models/RefreshToken";

export interface AccessPayload {
  sub: string;
  email: string;
  type: "access";
}

function hashToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}

function parseDurationToMs(value: string): number {
  const match = /^(\d+)([smhd])$/.exec(value);
  if (!match) {
    // fallback 30 days
    return 30 * 24 * 60 * 60 * 1000;
  }
  const n = Number(match[1]);
  const unit = match[2];
  const mult: Record<string, number> = {
    s: 1000,
    m: 60 * 1000,
    h: 60 * 60 * 1000,
    d: 24 * 60 * 60 * 1000,
  };
  return n * (mult[unit] ?? 1000);
}

export function signAccessToken(userId: string, email: string): string {
  const payload: AccessPayload = { sub: userId, email, type: "access" };
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
    expiresIn: env.JWT_ACCESS_EXPIRES_IN as jwt.SignOptions["expiresIn"],
  });
}

export function verifyAccessToken(token: string): AccessPayload {
  const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as AccessPayload;
  if (decoded.type !== "access") {
    throw new Error("Invalid token type");
  }
  return decoded;
}

export async function issueRefreshToken(
  userId: Types.ObjectId | string,
  userAgent?: string
): Promise<{ refreshToken: string; expiresAt: Date }> {
  const refreshToken = crypto.randomBytes(48).toString("base64url");
  const tokenHash = hashToken(refreshToken);
  const expiresAt = new Date(Date.now() + parseDurationToMs(env.JWT_REFRESH_EXPIRES_IN));

  await RefreshToken.create({
    userId,
    tokenHash,
    expiresAt,
    userAgent,
  });

  return { refreshToken, expiresAt };
}

export async function rotateRefreshToken(
  oldRefreshToken: string,
  userAgent?: string
): Promise<{ userId: string; refreshToken: string; expiresAt: Date } | null> {
  const tokenHash = hashToken(oldRefreshToken);
  const existing = await RefreshToken.findOne({ tokenHash });

  if (!existing || existing.revokedAt || existing.expiresAt.getTime() < Date.now()) {
    return null;
  }

  // Revoke old token (rotation)
  existing.revokedAt = new Date();
  await existing.save();

  const issued = await issueRefreshToken(existing.userId, userAgent);
  return {
    userId: existing.userId.toString(),
    refreshToken: issued.refreshToken,
    expiresAt: issued.expiresAt,
  };
}

export async function revokeRefreshToken(refreshToken: string): Promise<void> {
  const tokenHash = hashToken(refreshToken);
  await RefreshToken.updateOne(
    { tokenHash, revokedAt: { $exists: false } },
    { $set: { revokedAt: new Date() } }
  );
}

export async function revokeAllUserRefreshTokens(userId: string): Promise<void> {
  await RefreshToken.updateMany(
    { userId, revokedAt: { $exists: false } },
    { $set: { revokedAt: new Date() } }
  );
}
