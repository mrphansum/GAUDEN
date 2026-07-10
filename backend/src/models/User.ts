/**
 * User model — tài khoản người dùng (email/password hoặc Google).
 *
 * Giải thích:
 * - passwordHash optional vì user Google có thể không có mật khẩu local.
 * - googleId dùng để map ổn định với tài khoản Google (Gmail).
 * - Không bao giờ trả passwordHash ra API (toJSON transform).
 */
import mongoose, { Document, Schema, Types } from "mongoose";

export type AuthProvider = "local" | "google";

export interface IUser extends Document {
  _id: Types.ObjectId;
  email: string;
  name: string;
  passwordHash?: string;
  googleId?: string;
  providers: AuthProvider[];
  avatarUrl?: string;
  createdAt: Date;
  updatedAt: Date;
}

const userSchema = new Schema<IUser>(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    name: { type: String, required: true, trim: true },
    passwordHash: { type: String, required: false, select: false },
    googleId: { type: String, required: false, sparse: true, unique: true },
    providers: {
      type: [String],
      enum: ["local", "google"],
      default: ["local"],
    },
    avatarUrl: { type: String },
  },
  { timestamps: true }
);

userSchema.set("toJSON", {
  transform(_doc, ret) {
    const obj = ret as unknown as Record<string, unknown>;
    delete obj.passwordHash;
    delete obj.__v;
    return obj;
  },
});

export const User = mongoose.model<IUser>("User", userSchema);
