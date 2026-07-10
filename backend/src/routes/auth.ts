/**
 * Auth routes — register/login (email), Google Gmail, refresh, logout.
 */
import { Router, Request, Response, NextFunction } from "express";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { User } from "../models/User";
import {
  issueRefreshToken,
  revokeRefreshToken,
  rotateRefreshToken,
  signAccessToken,
} from "../services/tokenService";
import {
  findOrCreateGoogleUser,
  verifyGoogleIdToken,
} from "../services/googleAuthService";
import { requireAuth } from "../middleware/auth";

const router = Router();

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(128),
  name: z.string().min(1).max(80),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const googleSchema = z.object({
  idToken: z.string().min(10),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(10),
});

function publicUser(user: {
  _id: { toString(): string };
  email: string;
  name: string;
  avatarUrl?: string;
  providers: string[];
}) {
  return {
    id: user._id.toString(),
    email: user.email,
    name: user.name,
    avatarUrl: user.avatarUrl ?? null,
    providers: user.providers,
  };
}

async function issueAuthResponse(
  res: Response,
  user: {
    _id: { toString(): string };
    email: string;
    name: string;
    avatarUrl?: string;
    providers: string[];
  },
  userAgent?: string
) {
  const userId = user._id.toString();
  const accessToken = signAccessToken(userId, user.email);
  const { refreshToken, expiresAt } = await issueRefreshToken(userId, userAgent);
  res.json({
    user: publicUser(user),
    tokens: {
      accessToken,
      refreshToken,
      refreshExpiresAt: expiresAt.toISOString(),
      tokenType: "Bearer",
    },
  });
}

/** POST /api/auth/register — đăng ký email/password */
router.post("/register", async (req: Request, res: Response, next: NextFunction) => {
  try {
    const body = registerSchema.parse(req.body);
    const email = body.email.toLowerCase();
    const exists = await User.findOne({ email });
    if (exists) {
      res.status(409).json({ error: "EmailAlreadyUsed", message: "Email already registered" });
      return;
    }
    const passwordHash = await bcrypt.hash(body.password, 12);
    const user = await User.create({
      email,
      name: body.name,
      passwordHash,
      providers: ["local"],
    });
    await issueAuthResponse(res, user, req.get("user-agent") || undefined);
  } catch (e) {
    next(e);
  }
});

/** POST /api/auth/login */
router.post("/login", async (req: Request, res: Response, next: NextFunction) => {
  try {
    const body = loginSchema.parse(req.body);
    const email = body.email.toLowerCase();
    const user = await User.findOne({ email }).select("+passwordHash");
    if (!user || !user.passwordHash) {
      res.status(401).json({ error: "InvalidCredentials", message: "Invalid email or password" });
      return;
    }
    const ok = await bcrypt.compare(body.password, user.passwordHash);
    if (!ok) {
      res.status(401).json({ error: "InvalidCredentials", message: "Invalid email or password" });
      return;
    }
    await issueAuthResponse(res, user, req.get("user-agent") || undefined);
  } catch (e) {
    next(e);
  }
});

/**
 * POST /api/auth/google — đăng ký / đăng nhập bằng Gmail (Google idToken)
 * Body: { idToken: string }
 */
router.post("/google", async (req: Request, res: Response, next: NextFunction) => {
  try {
    const body = googleSchema.parse(req.body);
    const profile = await verifyGoogleIdToken(body.idToken);
    if (!profile.emailVerified && process.env.NODE_ENV === "production") {
      res.status(400).json({ error: "EmailNotVerified", message: "Google email not verified" });
      return;
    }
    const user = await findOrCreateGoogleUser(profile);
    await issueAuthResponse(res, user, req.get("user-agent") || undefined);
  } catch (e) {
    next(e);
  }
});

/** POST /api/auth/refresh — rotate refresh token, cấp access mới */
router.post("/refresh", async (req: Request, res: Response, next: NextFunction) => {
  try {
    const body = refreshSchema.parse(req.body);
    const rotated = await rotateRefreshToken(
      body.refreshToken,
      req.get("user-agent") || undefined
    );
    if (!rotated) {
      res.status(401).json({ error: "InvalidRefreshToken", message: "Refresh token invalid or expired" });
      return;
    }
    const user = await User.findById(rotated.userId);
    if (!user) {
      res.status(401).json({ error: "InvalidRefreshToken", message: "User not found" });
      return;
    }
    const accessToken = signAccessToken(user._id.toString(), user.email);
    res.json({
      user: publicUser(user),
      tokens: {
        accessToken,
        refreshToken: rotated.refreshToken,
        refreshExpiresAt: rotated.expiresAt.toISOString(),
        tokenType: "Bearer",
      },
    });
  } catch (e) {
    next(e);
  }
});

/** POST /api/auth/logout */
router.post("/logout", async (req: Request, res: Response, next: NextFunction) => {
  try {
    const body = refreshSchema.partial().parse(req.body ?? {});
    if (body.refreshToken) {
      await revokeRefreshToken(body.refreshToken);
    }
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

/** GET /api/auth/me — alias nhẹ; profile chi tiết ở /api/me */
router.get("/me", requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await User.findById(req.user!.id);
    if (!user) {
      res.status(404).json({ error: "NotFound" });
      return;
    }
    res.json({ user: publicUser(user) });
  } catch (e) {
    next(e);
  }
});

export default router;
