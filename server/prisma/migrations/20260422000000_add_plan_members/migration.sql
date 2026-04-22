-- CreateEnum
CREATE TYPE "PlanMemberStatus" AS ENUM ('invited', 'accepted', 'declined');

-- CreateTable
CREATE TABLE "plan_members" (
    "id" TEXT NOT NULL,
    "plan_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "status" "PlanMemberStatus" NOT NULL DEFAULT 'invited',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "plan_members_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "plan_members_user_id_idx" ON "plan_members"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "plan_members_plan_id_user_id_key" ON "plan_members"("plan_id", "user_id");

-- AddForeignKey
ALTER TABLE "plan_members" ADD CONSTRAINT "plan_members_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "plans"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "plan_members" ADD CONSTRAINT "plan_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddUniqueConstraint on plan_items (delete any duplicates first, keeping the oldest)
DELETE FROM "plan_items" pi1
USING "plan_items" pi2
WHERE pi1."plan_id" = pi2."plan_id"
  AND pi1."item_type" = pi2."item_type"
  AND pi1."item_id" = pi2."item_id"
  AND pi1."created_at" > pi2."created_at";

-- CreateIndex
CREATE UNIQUE INDEX "plan_items_plan_id_item_type_item_id_key" ON "plan_items"("plan_id", "item_type", "item_id");
