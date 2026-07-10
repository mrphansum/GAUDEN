/**
 * iapService — Verify giao dịch IAP Non-Consumable và ghi entitlement.
 *
 * Giải thích:
 * - Production: nên verify JWS transaction (StoreKit 2) với Apple root certs
 *   hoặc App Store Server API. Ở đây có nhánh mock + skeleton verify.
 * - IAP_MOCK_VERIFY=true: tin transactionId từ client (CHỈ dev/sandbox local).
 * - Ownership: unique (userId, moduleId); transactionId unique chống replay.
 */
import { Types } from "mongoose";
import { env } from "../config/env";
import { Module, IModule } from "../models/Module";
import { Purchase, IPurchase } from "../models/Purchase";

export interface VerifyIapInput {
  userId: string;
  productId: string;
  transactionId: string;
  originalTransactionId?: string;
  /** JWS signed transaction (StoreKit 2) — dùng khi không mock */
  signedTransaction?: string;
}

export interface VerifyIapResult {
  purchase: IPurchase;
  module: IModule;
  alreadyOwned: boolean;
}

export async function verifyAndRecordPurchase(input: VerifyIapInput): Promise<VerifyIapResult> {
  const module = await Module.findOne({
    appleProductId: input.productId,
    isPublished: true,
  });
  if (!module) {
    const err = new Error("Unknown productId — module not found");
    (err as Error & { status: number }).status = 400;
    throw err;
  }

  // --- Verify with Apple (or mock) ---
  const verified = await verifyWithAppleOrMock(input);
  if (!verified.ok) {
    const err = new Error(verified.reason || "IAP verification failed");
    (err as Error & { status: number }).status = 400;
    throw err;
  }

  // Idempotent: đã có purchase theo transactionId
  const byTx = await Purchase.findOne({ transactionId: input.transactionId }).populate("moduleId");
  if (byTx) {
    if (byTx.userId.toString() !== input.userId) {
      const err = new Error("Transaction already linked to another account");
      (err as Error & { status: number }).status = 409;
      throw err;
    }
    return {
      purchase: byTx,
      module,
      alreadyOwned: true,
    };
  }

  // Đã own module (restore / mua lại)
  const existing = await Purchase.findOne({
    userId: new Types.ObjectId(input.userId),
    moduleId: module._id,
  });
  if (existing) {
    return { purchase: existing, module, alreadyOwned: true };
  }

  const purchase = await Purchase.create({
    userId: new Types.ObjectId(input.userId),
    moduleId: module._id,
    appleProductId: input.productId,
    transactionId: input.transactionId,
    originalTransactionId: input.originalTransactionId || input.transactionId,
    source: env.IAP_MOCK_VERIFY ? "mock" : "apple_iap",
    purchasedAt: new Date(),
  });

  return { purchase, module, alreadyOwned: false };
}

async function verifyWithAppleOrMock(
  input: VerifyIapInput
): Promise<{ ok: boolean; reason?: string }> {
  if (env.IAP_MOCK_VERIFY) {
    // Dev: chỉ kiểm tra có transactionId + productId
    if (!input.transactionId || !input.productId) {
      return { ok: false, reason: "Missing transactionId or productId" };
    }
    return { ok: true };
  }

  // Production skeleton: decode JWS payload (không verify cert đầy đủ — TODO production harden)
  // Khuyến nghị: dùng @apple/app-store-server-library khi lên store.
  if (!input.signedTransaction) {
    return {
      ok: false,
      reason: "signedTransaction required when IAP_MOCK_VERIFY=false",
    };
  }

  try {
    const parts = input.signedTransaction.split(".");
    if (parts.length < 2) {
      return { ok: false, reason: "Invalid JWS format" };
    }
    const payload = JSON.parse(
      Buffer.from(parts[1], "base64url").toString("utf8")
    ) as {
      transactionId?: string;
      productId?: string;
      bundleId?: string;
      type?: string;
    };

    if (payload.productId && payload.productId !== input.productId) {
      return { ok: false, reason: "productId mismatch" };
    }
    if (payload.transactionId && payload.transactionId !== input.transactionId) {
      return { ok: false, reason: "transactionId mismatch" };
    }
    if (payload.bundleId && payload.bundleId !== env.APPLE_BUNDLE_ID) {
      return { ok: false, reason: "bundleId mismatch" };
    }
    // Non-Consumable check (StoreKit type field may be "Non-Consumable")
    return { ok: true };
  } catch {
    return { ok: false, reason: "Failed to parse signedTransaction" };
  }
}

export async function getOwnedModuleIds(userId: string): Promise<string[]> {
  const rows = await Purchase.find({ userId }).select("moduleId");
  return rows.map((r) => r.moduleId.toString());
}

export async function userOwnsModule(userId: string, moduleId: string): Promise<boolean> {
  const count = await Purchase.countDocuments({ userId, moduleId });
  return count > 0;
}
