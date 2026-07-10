/**
 * index.ts — Entry point: connect MongoDB rồi listen HTTP.
 *
 * Windows:
 *   1. Cài Node.js LTS + MongoDB
 *   2. copy .env.example -> .env
 *   3. npm install && npm run seed && npm run dev
 */
import mongoose from "mongoose";
import { env } from "./config/env";
import { createApp } from "./app";

async function main() {
  console.log("Connecting MongoDB...", env.MONGODB_URI);
  await mongoose.connect(env.MONGODB_URI);
  console.log("MongoDB connected");

  const app = createApp();
  app.listen(env.PORT, "0.0.0.0", () => {
    console.log(`Home Application Fix API listening on http://0.0.0.0:${env.PORT}`);
    console.log(`Health: http://localhost:${env.PORT}/health`);
    console.log(`IAP mock verify: ${env.IAP_MOCK_VERIFY}`);
  });
}

main().catch((err) => {
  console.error("Fatal startup error:", err);
  process.exit(1);
});
