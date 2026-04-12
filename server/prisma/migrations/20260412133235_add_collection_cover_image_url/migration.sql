-- AlterTable
ALTER TABLE "collections" ADD COLUMN     "cover_image_url" TEXT;

-- AddForeignKey
ALTER TABLE "saves" ADD CONSTRAINT "saves_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "collections"("id") ON DELETE SET NULL ON UPDATE CASCADE;
