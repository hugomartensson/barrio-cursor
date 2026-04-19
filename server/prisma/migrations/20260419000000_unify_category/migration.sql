-- Migration: Unify category field on spots and events
-- 1. Add nullable category column to spots (using existing Category enum)
ALTER TABLE "spots" ADD COLUMN "category" "Category";

-- 2. Backfill from category_tag, defaulting to 'community' for nulls / unrecognised values
UPDATE "spots"
SET "category" = CASE
  WHEN "category_tag" IN ('food','drinks','music','art','markets','community')
    THEN "category_tag"::"Category"
  ELSE 'community'::"Category"
END;

-- 3. Make category NOT NULL now that every row has a value
ALTER TABLE "spots" ALTER COLUMN "category" SET NOT NULL;

-- 4. Add index on spots.category, drop old index on category_tag
CREATE INDEX "spots_category_idx" ON "spots"("category");
DROP INDEX IF EXISTS "spots_category_tag_idx";

-- 5. Drop redundant columns from spots
ALTER TABLE "spots" DROP COLUMN IF EXISTS "category_tag";
ALTER TABLE "spots" DROP COLUMN IF EXISTS "tags";

-- 6. Drop redundant columns from events
DROP INDEX IF EXISTS "events_category_tag_idx";
ALTER TABLE "events" DROP COLUMN IF EXISTS "category_tag";
ALTER TABLE "events" DROP COLUMN IF EXISTS "tags";
