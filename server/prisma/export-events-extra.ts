/**
 * Export the 200 events created by seed-bcn-events-extra.ts from the local DB
 * into a JSON file that can be replayed against another DB (e.g. Railway prod).
 *
 * Identification: events created by the extra seeder are the only ones in the
 * DB with spotId IS NOT NULL (the original seed-bcn-mock.ts leaves spotId null).
 *
 * Usage:  cd server && npm run events:export
 * Output: prisma/events-extra.json
 */

import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { writeFileSync } from 'fs';
import { join } from 'path';

const prisma = new PrismaClient();

interface ExportedEvent {
  ownerEmail: string;
  spotKey: { name: string; address: string; ownerEmail: string };
  title: string;
  description: string;
  category: string;
  address: string;
  neighborhood: string | null;
  latitude: number;
  longitude: number;
  startTime: string;
  endTime: string | null;
  saveCount: number;
  media: { url: string; type: string; order: number }[];
}

async function main() {
  console.log('📦 Exporting extra events from local DB...\n');

  const events = await prisma.event.findMany({
    where: { spotId: { not: null } },
    include: {
      user: { select: { email: true } },
      spot: {
        select: {
          name: true,
          address: true,
          owner: { select: { email: true } },
        },
      },
      media: { orderBy: { order: 'asc' } },
    },
    orderBy: { createdAt: 'asc' },
  });

  console.log(`   Found ${events.length} events with spotId set`);

  const exported: ExportedEvent[] = events.map((e) => {
    if (!e.spot) throw new Error(`Event ${e.id} has spotId but spot is null`);
    return {
      ownerEmail: e.user.email,
      spotKey: {
        name: e.spot.name,
        address: e.spot.address,
        ownerEmail: e.spot.owner.email,
      },
      title: e.title,
      description: e.description,
      category: e.category,
      address: e.address,
      neighborhood: e.neighborhood,
      latitude: e.latitude,
      longitude: e.longitude,
      startTime: e.startTime.toISOString(),
      endTime: e.endTime ? e.endTime.toISOString() : null,
      saveCount: e.saveCount,
      media: e.media.map((m) => ({ url: m.url, type: m.type, order: m.order })),
    };
  });

  const totalMedia = exported.reduce((sum, e) => sum + e.media.length, 0);
  const outPath = join(process.cwd(), 'prisma', 'events-extra.json');
  writeFileSync(outPath, JSON.stringify(exported, null, 2), 'utf8');

  console.log(`\n✅ Exported ${exported.length} events with ${totalMedia} media items`);
  console.log(`   → ${outPath}`);

  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error(e);
  await prisma.$disconnect();
  process.exit(1);
});
