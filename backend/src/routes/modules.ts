/**
 * Modules routes — catalog công khai + full content (cần entitlement).
 */
import { Router, Request, Response, NextFunction } from "express";
import { Module } from "../models/Module";
import { optionalAuth, requireAuth } from "../middleware/auth";
import { getOwnedModuleIds, userOwnsModule } from "../services/iapService";

const router = Router();

function toListItem(
  m: {
    _id: { toString(): string };
    slug: string;
    title: string;
    subtitle?: string;
    description: string;
    category: string;
    appleProductId: string;
    coverImageUrl?: string;
    demoContent: unknown[];
    sortOrder: number;
  },
  owned: boolean
) {
  return {
    id: m._id.toString(),
    slug: m.slug,
    title: m.title,
    subtitle: m.subtitle ?? null,
    description: m.description,
    category: m.category,
    appleProductId: m.appleProductId,
    coverImageUrl: m.coverImageUrl ?? null,
    demoCount: m.demoContent?.length ?? 0,
    owned,
    sortOrder: m.sortOrder,
  };
}

/** GET /api/modules — danh sách module (+ owned nếu đã login) */
router.get("/", optionalAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const modules = await Module.find({ isPublished: true }).sort({ sortOrder: 1, title: 1 });
    let ownedSet = new Set<string>();
    if (req.user) {
      const ids = await getOwnedModuleIds(req.user.id);
      ownedSet = new Set(ids);
    }
    const category = typeof req.query.category === "string" ? req.query.category : null;
    const filtered = category
      ? modules.filter((m) => m.category.toLowerCase() === category.toLowerCase())
      : modules;

    res.json({
      modules: filtered.map((m) => toListItem(m, ownedSet.has(m._id.toString()))),
      categories: [...new Set(modules.map((m) => m.category))],
    });
  } catch (e) {
    next(e);
  }
});

/** GET /api/modules/:idOrSlug — chi tiết + demo content (full chỉ khi owned) */
router.get("/:idOrSlug", optionalAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const key = req.params.idOrSlug;
    const query = key.match(/^[a-f\d]{24}$/i) ? { _id: key } : { slug: key };
    const m = await Module.findOne({ ...query, isPublished: true });
    if (!m) {
      res.status(404).json({ error: "NotFound", message: "Module not found" });
      return;
    }

    let owned = false;
    if (req.user) {
      owned = await userOwnsModule(req.user.id, m._id.toString());
    }

    res.json({
      module: {
        ...toListItem(m, owned),
        demoContent: m.demoContent,
        // fullContent chỉ trả khi đã mua — guest/chưa mua không thấy URL full
        fullContent: owned ? m.fullContent : null,
        requiresPurchase: !owned,
      },
    });
  } catch (e) {
    next(e);
  }
});

/**
 * GET /api/modules/:idOrSlug/content — full content bắt buộc auth + ownership
 */
router.get(
  "/:idOrSlug/content",
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const key = req.params.idOrSlug;
      const query = key.match(/^[a-f\d]{24}$/i) ? { _id: key } : { slug: key };
      const m = await Module.findOne({ ...query, isPublished: true });
      if (!m) {
        res.status(404).json({ error: "NotFound" });
        return;
      }
      const owned = await userOwnsModule(req.user!.id, m._id.toString());
      if (!owned) {
        res.status(403).json({
          error: "PurchaseRequired",
          message: "Buy this module to access full content",
          appleProductId: m.appleProductId,
        });
        return;
      }
      res.json({
        moduleId: m._id.toString(),
        title: m.title,
        fullContent: m.fullContent,
      });
    } catch (e) {
      next(e);
    }
  }
);

export default router;
