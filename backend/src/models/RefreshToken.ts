/**
 * RefreshToken model — lưu hash của refresh token (không lưu plain text).
 *
 * Giải thích:
 * - Khi login/refresh: server tạo refresh token ngẫu nhiên, hash SHA-256, lưu DB.
 * - Rotation: mỗi lần refresh, token cũ bị revoke, cấp token mới.
 * - Logout: revoke token hiện tại (hoặc toàn bộ token của user).
 */
import mongoose, { Document, Schema, Types } from "mongoose";

export interface IRefreshToken extends Document {
  userId: Types.ObjectId;
  tokenHash: string;
  expiresAt: Date;
  revokedAt?: Date;
  createdAt: Date;
  userAgent?: string;
}

const refreshTokenSchema = new Schema<IRefreshToken>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    tokenHash: { type: String, required: true, unique: true },
    expiresAt: { type: Date, required: true, index: true },
    revokedAt: { type: Date },
    userAgent: { type: String },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

// TTL index: Mongo tự xóa document hết hạn (an toàn thêm, vẫn check expiresAt khi verify)
refreshTokenSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export const RefreshToken = mongoose.model<IRefreshToken>("RefreshToken", refreshTokenSchema);
