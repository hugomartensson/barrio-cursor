-- Migration: Update schema to match PRD-TestFlight requirements
-- This migration adds new features (Follow, FollowRequest, Plans) and replaces Like/Going with Interested

-- CreateEnum
CREATE TYPE "FollowRequestStatus" AS ENUM ('pending', 'accepted', 'declined');

-- AlterTable: Add new columns to users
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "is_private" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "follower_count" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "following_count" INTEGER NOT NULL DEFAULT 0;

-- AlterTable: Update events table
-- Add new columns
ALTER TABLE "events" ADD COLUMN IF NOT EXISTS "address" TEXT;
ALTER TABLE "events" ADD COLUMN IF NOT EXISTS "is_free" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "events" ADD COLUMN IF NOT EXISTS "interested_count" INTEGER NOT NULL DEFAULT 0;

-- Migrate data: Copy likes to interested_count (if likes_count exists)
UPDATE "events" SET "interested_count" = COALESCE("likes_count", 0) WHERE "interested_count" = 0;

-- Drop old columns from events (if they exist)
ALTER TABLE "events" DROP COLUMN IF EXISTS "likes_count";
ALTER TABLE "events" DROP COLUMN IF EXISTS "going_count";

-- AlterTable: Add thumbnail_url to media_items
ALTER TABLE "media_items" ADD COLUMN IF NOT EXISTS "thumbnail_url" TEXT;

-- CreateTable: interested (replaces likes)
CREATE TABLE IF NOT EXISTS "interested" (
    "user_id" TEXT NOT NULL,
    "event_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "interested_pkey" PRIMARY KEY ("user_id","event_id")
);

-- Migrate data: Copy from likes to interested
INSERT INTO "interested" ("user_id", "event_id", "created_at")
SELECT "user_id", "event_id", "created_at" FROM "likes"
ON CONFLICT DO NOTHING;

-- CreateTable: follows
CREATE TABLE IF NOT EXISTS "follows" (
    "follower_id" TEXT NOT NULL,
    "following_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "follows_pkey" PRIMARY KEY ("follower_id","following_id")
);

-- CreateTable: follow_requests
CREATE TABLE IF NOT EXISTS "follow_requests" (
    "id" TEXT NOT NULL,
    "from_user_id" TEXT NOT NULL,
    "to_user_id" TEXT NOT NULL,
    "status" "FollowRequestStatus" NOT NULL DEFAULT 'pending',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "follow_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable: plans
CREATE TABLE IF NOT EXISTS "plans" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "is_archived" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "plans_pkey" PRIMARY KEY ("id")
);

-- CreateTable: plan_events
CREATE TABLE IF NOT EXISTS "plan_events" (
    "plan_id" TEXT NOT NULL,
    "event_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "plan_events_pkey" PRIMARY KEY ("plan_id","event_id")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "follow_requests_to_user_id_idx" ON "follow_requests"("to_user_id");
CREATE INDEX IF NOT EXISTS "plans_user_id_idx" ON "plans"("user_id");

-- AddForeignKey
ALTER TABLE "interested" ADD CONSTRAINT "interested_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "interested" ADD CONSTRAINT "interested_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "follows" ADD CONSTRAINT "follows_follower_id_fkey" FOREIGN KEY ("follower_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "follows" ADD CONSTRAINT "follows_following_id_fkey" FOREIGN KEY ("following_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "follow_requests" ADD CONSTRAINT "follow_requests_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "follow_requests" ADD CONSTRAINT "follow_requests_to_user_id_fkey" FOREIGN KEY ("to_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "plans" ADD CONSTRAINT "plans_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "plan_events" ADD CONSTRAINT "plan_events_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "plans"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "plan_events" ADD CONSTRAINT "plan_events_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Drop old tables (after data migration)
DROP TABLE IF EXISTS "going";
DROP TABLE IF EXISTS "likes";
