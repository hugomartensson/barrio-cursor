-- Decouple saves from collections.
-- Saves represent "user bookmarked this item" independently of any collection.
-- CollectionItem is the join table for explicit "item belongs to collection" membership.

-- Step 1: Drop old primary key (userId, collectionId, itemId)
ALTER TABLE "saves" DROP CONSTRAINT "saves_pkey";

-- Step 2: Deduplicate: if a user somehow saved the same item multiple times
-- (different collectionIds), keep only the most recent row.
DELETE FROM "saves" s1
USING "saves" s2
WHERE s1.user_id = s2.user_id
  AND s1.item_type = s2.item_type
  AND s1.item_id = s2.item_id
  AND s1.created_at < s2.created_at;

-- Step 3: Drop the foreign-key constraint from saves to collections
ALTER TABLE "saves" DROP CONSTRAINT IF EXISTS "saves_collection_id_fkey";

-- Step 4: Make collection_id nullable
ALTER TABLE "saves" ALTER COLUMN "collection_id" DROP NOT NULL;

-- Step 5: NULL out all existing collection_id values (decouple saves from the
-- auto-created "Saved" collection so they are pure bookmarks)
UPDATE "saves" SET "collection_id" = NULL;

-- Step 6: Add new primary key on (user_id, item_type, item_id)
ALTER TABLE "saves" ADD CONSTRAINT "saves_pkey" PRIMARY KEY ("user_id", "item_type", "item_id");

-- Step 7: Delete auto-created "Saved" collections (now safe: no FK references them)
DELETE FROM "collections" WHERE "name" = 'Saved';
