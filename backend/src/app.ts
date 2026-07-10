/**
 * app.ts — Express app wiring (không listen — listen ở index.ts).
 *
 * Giải thích:
 * - helmet: header bảo mật cơ bản
 * - cors: cho phép iOS simulator / device gọi API
 * - rate-limit: giảm brute-force login
 * - morgan: log request khi dev
 */
import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import rateLimit from "express-rate-limit";
import { env } from "./config/env";
import { errorHandler, notFound } from "./middleware/errorHandler";
import authRoutes from "./routes/auth";
import modulesRoutes from "./routes/modules";
import iapRoutes from "./routes/iap";
import meRoutes from "./routes/me";

export function createApp() {
  const app = express();

  app.use(helmet());
  app.use(
    cors({
      origin: env.CORS_ORIGIN === "*" ? true : env.CORS_ORIGIN.split(",").map((s) => s.trim()),
      credentials: true,
    })
  );
  app.use(express.json({ limit: "1mb" }));
  if (env.NODE_ENV !== "test") {
    app.use(morgan(env.NODE_ENV === "production" ? "combined" : "dev"));
  }

  const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    standardHeaders: true,
    legacyHeaders: false,
  });

  app.get("/health", (_req, res) => {
    res.json({
      ok: true,
      service: "Home Application Fix API",
      env: env.NODE_ENV,
      iapMock: env.IAP_MOCK_VERIFY,
    });
  });

  app.use("/api/auth", authLimiter, authRoutes);
  app.use("/api/modules", modulesRoutes);
  app.use("/api/iap", iapRoutes);
  app.use("/api/me", meRoutes);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}
