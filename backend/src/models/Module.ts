/**
 * Module model — gói bán dạng Add-on / DLC (Non-Consumable IAP).
 *
 * Giải thích:
 * - Mỗi module map 1 appleProductId (StoreKit Non-Consumable).
 * - demoContent: xem free (không cần mua).
 * - fullContent: chỉ user có entitlement.
 * - category hỗ trợ UI danh mục; dễ thêm gói sau bằng seed/API.
 */
import mongoose, { Document, Schema } from "mongoose";

export interface IContentItem {
  type: "document" | "video";
  title: string;
  /** URL demo hoặc full — có thể là https hoặc path tương đối */
  url: string;
  description?: string;
  durationSeconds?: number;
}

export interface IModule extends Document {
  slug: string;
  title: string;
  subtitle?: string;
  description: string;
  category: string;
  /** Apple IAP product id, ví dụ com.mrphansum.homeapplicationfix.module1 */
  appleProductId: string;
  sortOrder: number;
  isPublished: boolean;
  coverImageUrl?: string;
  demoContent: IContentItem[];
  fullContent: IContentItem[];
  createdAt: Date;
  updatedAt: Date;
}

const contentItemSchema = new Schema<IContentItem>(
  {
    type: { type: String, enum: ["document", "video"], required: true },
    title: { type: String, required: true },
    url: { type: String, required: true },
    description: { type: String },
    durationSeconds: { type: Number },
  },
  { _id: false }
);

const moduleSchema = new Schema<IModule>(
  {
    slug: { type: String, required: true, unique: true, index: true },
    title: { type: String, required: true },
    subtitle: { type: String },
    description: { type: String, required: true },
    category: { type: String, required: true, index: true },
    appleProductId: { type: String, required: true, unique: true },
    sortOrder: { type: Number, default: 0 },
    isPublished: { type: Boolean, default: true },
    coverImageUrl: { type: String },
    demoContent: { type: [contentItemSchema], default: [] },
    fullContent: { type: [contentItemSchema], default: [] },
  },
  { timestamps: true }
);

export const Module = mongoose.model<IModule>("Module", moduleSchema);
