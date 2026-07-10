/**
 * env.ts — Đọc và validate biến môi trường lúc khởi động.
 *
 * Giải thích:
 * - Dùng Zod để fail-fast nếu thiếu secret quan trọng.
 * - Tránh hardcode secret trong code; chỉ lấy từ process.env / file .env.
 */
import dotenv from "dotenv";
import { z } from "zod";

dotenv.config();

const envSchema = z.object({
  PORT: z.coerce.number().default(4000),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  MONGODB_URI: z.string().min(1),
  JWT_ACCESS_SECRET: z.string().min(16),
  JWT_REFRESH_SECRET: z.string().min(16),
  JWT_ACCESS_EXPIRES_IN: z.string().default("15m"),
  JWT_REFRESH_EXPIRES_IN: z.string().default("30d"),
  GOOGLE_CLIENT_ID: z.string().optional().default(""),
  GOOGLE_IOS_CLIENT_ID: z.string().optional().default(""),
  IAP_MOCK_VERIFY: z
    .string()
    .optional()
    .transform((v) => v !== "false" && v !== "0"),
  CORS_ORIGIN: z.string().default("*"),
  APPLE_BUNDLE_ID: z.string().optional().default("com.mrphansum.homeapplicationfix"),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error("❌ Invalid environment variables:");
  console.error(parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
