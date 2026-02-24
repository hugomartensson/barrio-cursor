/*
  Warnings:

  - The values [food_drink,arts_culture,nightlife,sports_outdoors] on the enum `Category` will be removed. If these variants are still used in the database, this will fail.
  - The values [video] on the enum `MediaType` will be removed. If these variants are still used in the database, this will fail.
  - You are about to drop the column `is_free` on the `events` table. All the data in the column will be lost.
  - You are about to drop the column `location` on the `events` table. All the data in the column will be lost.
  - You are about to drop the column `saves_count` on the `events` table. All the data in the column will be lost.
  - You are about to drop the column `source_type` on the `events` table. All the data in the column will be lost.
  - You are about to drop the column `source_url` on the `events` table. All the data in the column will be lost.
  - You are about to drop the column `time_slot` on the `events` table. All the data in the column will be lost.
  - You are about to drop the column `venue_name` on the `events` table. All the data in the column will be lost.
  - You are about to drop the column `location` on the `spots` table. All the data in the column will be lost.
  - You are about to drop the `plan_events` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `plans` table. If the table is not empty, all the data it contains will be lost.

*/
-- AlterEnum
BEGIN;
CREATE TYPE "Category_new" AS ENUM ('food', 'drinks', 'music', 'art', 'markets', 'community');
ALTER TABLE "events" ALTER COLUMN "category" TYPE "Category_new" USING ("category"::text::"Category_new");
ALTER TYPE "Category" RENAME TO "Category_old";
ALTER TYPE "Category_new" RENAME TO "Category";
DROP TYPE "Category_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "MediaType_new" AS ENUM ('photo');
ALTER TABLE "media_items" ALTER COLUMN "type" TYPE "MediaType_new" USING ("type"::text::"MediaType_new");
ALTER TYPE "MediaType" RENAME TO "MediaType_old";
ALTER TYPE "MediaType_new" RENAME TO "MediaType";
DROP TYPE "MediaType_old";
COMMIT;

-- DropForeignKey
ALTER TABLE "plan_events" DROP CONSTRAINT "plan_events_event_id_fkey";

-- DropForeignKey
ALTER TABLE "plan_events" DROP CONSTRAINT "plan_events_plan_id_fkey";

-- DropForeignKey
ALTER TABLE "plans" DROP CONSTRAINT "plans_collection_id_fkey";

-- DropForeignKey
ALTER TABLE "plans" DROP CONSTRAINT "plans_user_id_fkey";

-- DropIndex
DROP INDEX "events_location_idx";

-- DropIndex
DROP INDEX "spots_location_idx";

-- AlterTable
ALTER TABLE "events" DROP COLUMN "is_free",
DROP COLUMN "location",
DROP COLUMN "saves_count",
DROP COLUMN "source_type",
DROP COLUMN "source_url",
DROP COLUMN "time_slot",
DROP COLUMN "venue_name",
ADD COLUMN     "save_count" INTEGER NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "spots" DROP COLUMN "location",
ADD COLUMN     "save_count" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "tags" TEXT[];

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "selected_city" TEXT;

-- DropTable
DROP TABLE "plan_events";

-- DropTable
DROP TABLE "plans";

-- CreateTable
CREATE TABLE "saved_collections" (
    "user_id" TEXT NOT NULL,
    "collection_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "saved_collections_pkey" PRIMARY KEY ("user_id","collection_id")
);

-- CreateIndex
CREATE INDEX "saved_collections_user_id_idx" ON "saved_collections"("user_id");

-- CreateIndex
CREATE INDEX "saved_collections_collection_id_idx" ON "saved_collections"("collection_id");

-- AddForeignKey
ALTER TABLE "saved_collections" ADD CONSTRAINT "saved_collections_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "saved_collections" ADD CONSTRAINT "saved_collections_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "collections"("id") ON DELETE CASCADE ON UPDATE CASCADE;
