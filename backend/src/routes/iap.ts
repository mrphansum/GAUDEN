/**
 * IAP routes — client gửi transaction sau StoreKit purchase / restore.
 */
import { Router, Request, Response, NextFunction } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth";
import { verifyAndRecordPurchase } from "../services/iapService";

const router = Router();

const verifySchema = z.object({
  productId: z.string().min(1),
  transactionId: z.string().min(1),
  originalTransactionId: z.string().optional(),
  signedTransaction: z.string().optional(),
});

/** POST /api/iap/verify */
router.post("/verify", requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const body = verifySchema.parse(req.body);
    const result = await verifyAndRecordPurchase({
      userId: req.user!.id,
      productId: body.productId,
      transactionId: body.transactionId,
      originalTransactionId: body.originalTransactionId,
      signedTransaction: body.signedTransaction,
    });

    res.json({
      ok: true,
      alreadyOwned: result.alreadyOwned,
      purchase: {
        id: result.purchase._id.toString(),
        moduleId: result.module._id.toString(),
        appleProductId: result.purchase.appleProductId,
        transactionId: result.purchase.transactionId,
        purchasedAt: result.purchase.purchasedAt,
        source: result.purchase.source,
      },
      module: {
        id: result.module._id.toString(),
        slug: result.module.slug,
        title: result.module.title,
      },
    });
  } catch (e) {
    next(e);
  }
});

export default router;
