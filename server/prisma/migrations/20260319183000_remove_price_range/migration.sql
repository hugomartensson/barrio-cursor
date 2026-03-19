-- AlterTable
ALTER TABLE "events" DROP COLUMN "price_range";

-- AlterTable
ALTER TABLE "spots" DROP COLUMN "price_range";

-- DropEnum
DROP TYPE "PriceRange";
