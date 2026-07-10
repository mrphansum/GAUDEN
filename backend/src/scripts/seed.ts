/**
 * seed.ts — Tạo Gói 1 (Module Add-on) mẫu.
 *
 * Chạy: npm run seed
 * Idempotent: upsert theo slug / appleProductId.
 */
import mongoose from "mongoose";
import { env } from "../config/env";
import { Module } from "../models/Module";

async function seed() {
  await mongoose.connect(env.MONGODB_URI);
  console.log("Seeding modules...");

  const module1 = {
    slug: "module-1-home-basics",
    title: "Gói 1 — Home Basics",
    subtitle: "Add-on / DLC đầu tiên",
    description:
      "Gói tài liệu và video hướng dẫn sửa chữa cơ bản tại nhà. Xem demo miễn phí; mua một lần (Non-Consumable) để mở toàn bộ nội dung.",
    category: "Home Repair",
    appleProductId: "com.mrphansum.homeapplicationfix.module1",
    sortOrder: 1,
    isPublished: true,
    coverImageUrl: "https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800",
    demoContent: [
      {
        type: "document" as const,
        title: "Demo — Checklist an toàn cơ bản",
        url: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
        description: "Tài liệu demo miễn phí (PDF mẫu).",
      },
      {
        type: "video" as const,
        title: "Demo — Giới thiệu gói 1",
        url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
        description: "Video demo miễn phí.",
        durationSeconds: 60,
      },
    ],
    fullContent: [
      {
        type: "document" as const,
        title: "Hướng dẫn đầy đủ — Sửa vòi nước rò rỉ",
        url: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
        description: "Nội dung full sau khi mua.",
      },
      {
        type: "document" as const,
        title: "Hướng dẫn đầy đủ — Thay bóng đèn & CB",
        url: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
      },
      {
        type: "video" as const,
        title: "Video full — Walkthrough sửa chữa",
        url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
        durationSeconds: 653,
      },
    ],
  };

  await Module.findOneAndUpdate(
    { slug: module1.slug },
    { $set: module1 },
    { upsert: true, new: true }
  );

  const count = await Module.countDocuments();
  console.log(`Done. Modules in DB: ${count}`);
  console.log(`Gói 1 productId: ${module1.appleProductId}`);
  await mongoose.disconnect();
}

seed().catch((e) => {
  console.error(e);
  process.exit(1);
});
