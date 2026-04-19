-- Add 'cafe' category to Category enum
-- ALTER TYPE ADD VALUE must run outside a transaction block.
-- Prisma handles this automatically for additive enum changes.
ALTER TYPE "Category" ADD VALUE IF NOT EXISTS 'cafe' BEFORE 'music';
