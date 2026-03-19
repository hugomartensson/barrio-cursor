-- CreateEnum
CREATE TYPE "DraftStatus" AS ENUM ('PENDING', 'APPROVED', 'SKIPPED', 'ERROR');

-- CreateTable
CREATE TABLE "drafts" (
    "id" TEXT NOT NULL,
    "status" "DraftStatus" NOT NULL DEFAULT 'PENDING',
    "input_type" TEXT NOT NULL,
    "source_url" TEXT,
    "raw_input" TEXT,
    "item_type" "ItemType",
    "name" TEXT,
    "description" TEXT,
    "category" "Category",
    "address" TEXT,
    "neighborhood" TEXT,
    "start_time" TIMESTAMP(3),
    "end_time" TIMESTAMP(3),
    "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "image_url" TEXT,
    "flagged_fields" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "collection_id" TEXT,
    "portal_id" TEXT,
    "error_message" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "drafts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "drafts_status_idx" ON "drafts"("status");

-- CreateIndex
CREATE INDEX "drafts_created_at_idx" ON "drafts"("created_at");
