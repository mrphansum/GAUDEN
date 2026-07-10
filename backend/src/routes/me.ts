/**
 * /api/me — profile + danh sách gói đã mua.
 */
import { Router, Request, Response, NextFunction } from "express";
import { requireAuth } from "../middleware/auth";
import { User } from "../models/User";
import { Purchase } from "../models/Purchase";
import { Module } from "../models/Module";

const router = Router();

router.get("/", requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await User.findById(req.user!.id);
    if (!user) {
      res.status(404).json({ error: "NotFound" });
      return;
    }
    res.json({
      user: {
        id: user._id.toString(),
        email: user.email,
        name: user.name,
        avatarUrl: user.avatarUrl ?? null,
        providers: user.providers,
        createdAt: user.createdAt,
      },
    });
  } catch (e) {
    next(e);
  }
});

/** GET /api/me/purchases — modules user đã mua (cho Profile UI) */
router.get("/purchases", requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const purchases = await Purchase.find({ userId: req.user!.id }).sort({ purchasedAt: -1 });
    const moduleIds = purchases.map((p) => p.moduleId);
    const modules = await Module.find({ _id: { $in: moduleIds } });
    const byId = new Map(modules.map((m) => [m._id.toString(), m]));

    res.json({
      purchases: purchases.map((p) => {
        const m = byId.get(p.moduleId.toString());
        return {
          id: p._id.toString(),
          purchasedAt: p.purchasedAt,
          appleProductId: p.appleProductId,
          transactionId: p.transactionId,
          source: p.source,
          module: m
            ? {
                id: m._id.toString(),
                slug: m.slug,
                title: m.title,
                subtitle: m.subtitle ?? null,
                category: m.category,
                coverImageUrl: m.coverImageUrl ?? null,
              }
            : null,
        };
      }),
    });
  } catch (e) {
    next(e);
  }
});

export default router;
