/**
 * Purchase / Entitlement — nguồn sự thật server-side về gói đã mua.
 *
 * Giải thích:
 * - Non-Consumable: 1 user + 1 module = tối đa 1 purchase active.
 * - transactionId/originalTransactionId từ Apple để chống double-claim & restore.
 * - App không được tự tin "đã mua"; chỉ tin sau /iap/verify thành công.
 */
import mongoose, { Document, Schema, Types } from "mongoose";

export type PurchaseSource = "apple_iap" | "mock" | "manual";

export interface IPurchase extends Document {
  userId: Types.ObjectId;
  moduleId: Types.ObjectId;
  appleProductId: string;
  transactionId: string;
  originalTransactionId?: string;
  source: PurchaseSource;
  purchasedAt: Date;
  createdAt: Date;
}

const purchaseSchema = new Schema<IPurchase>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    moduleId: { type: Schema.Types.ObjectId, ref: "Module", required: true, index: true },
    appleProductId: { type: String, required: true },
    transactionId: { type: String, required: true, unique: true },
    originalTransactionId: { type: String, index: true },
    source: { type: String, enum: ["apple_iap", "mock", "manual"], default: "apple_iap" },
    purchasedAt: { type: Date, default: Date.now },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

// Unique ownership per user+module for Non-Consumable
purchaseSchema.index({ userId: 1, moduleId: 1 }, { unique: true });

export const Purchase = mongoose.model<IPurchase>("Purchase", purchaseSchema);
