/**
 * Import events-extra.json into the database pointed to by DATABASE_URL.
 *
 * Resolves userId by email and spotId by (name + address + ownerEmail), since
 * UUIDs differ between local and production DBs that were seeded independently.
 *
 * Usage (against Railway prod):
 *   DATABASE_URL="postgresql://postgres:...@<host>.proxy.rlwy.net:<port>/railway" \
 *     npm run events:import
 */

import 'dotenv/config';
import { PrismaClient, Category, MediaType } from '@prisma/client';
import { readFileSync } from 'fs';
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
  const inputPath = join(process.cwd(), 'prisma', 'events-extra.json');
  const events = JSON.parse(readFileSync(inputPath, 'utf8')) as ExportedEvent[];

  console.log(`📥 Importing ${events.length} events from ${inputPath}\n`);
  console.log(`🎯 Target DB: ${process.env.DATABASE_URL?.replace(/:[^:@]+@/, ':***@')}\n`);

  // ── Pre-resolve all unique users + spots ─────────────────────────────────
  const ownerEmails = new Set(events.map((e) => e.ownerEmail));
  const spotOwnerEmails = new Set(events.map((e) => e.spotKey.ownerEmail));
  const allEmails = Array.from(new Set([...ownerEmails, ...spotOwnerEmails]));

  const users = await prisma.user.findMany({
    where: { email: { in: allEmails } },
    select: { id: true, email: true },
  });
  const userByEmail = new Map(users.map((u) => [u.email, u.id]));

  for (const email of allEmails) {
    if (!userByEmail.has(email)) {
      throw new Error(`User not found in target DB: ${email}. Run seed:bcn first.`);
    }
  }
  console.log(`   ✓ Resolved ${userByEmail.size} users`);

  // Resolve spots: lookup by (ownerId, name, address)
  const spotKeySet = new Map<string, { name: string; address: string; ownerEmail: string }>();
  for (const e of events) {
    const k = `${e.spotKey.ownerEmail}::${e.spotKey.name}::${e.spotKey.address}`;
    spotKeySet.set(k, e.spotKey);
  }

  const spotIdByKey = new Map<string, string>();
  for (const [k, key] of spotKeySet.entries()) {
    const ownerId = userByEmail.get(key.ownerEmail)!;
    const spot = await prisma.spot.findFirst({
      where: { ownerId, name: key.name, address: key.address },
      select: { id: true },
    });
    if (!spot) {
      throw new Error(
        `Spot not found in target DB: name="${key.name}" address="${key.address}" ownerEmail="${key.ownerEmail}". Run seed:bcn first.`
      );
    }
    spotIdByKey.set(k, spot.id);
  }
  console.log(`   ✓ Resolved ${spotIdByKey.size} spots\n`);

  // ── Insert events + media in a single transaction ────────────────────────
  console.log('💾 Inserting events + media...');
  let createdEvents = 0;
  let createdMedia = 0;

  await prisma.$transaction(
    async (tx) => {
      for (let i = 0; i < events.length; i++) {
        const e = events[i];
        const userId = userByEmail.get(e.ownerEmail)!;
        const spotId = spotIdByKey.get(
          `${e.spotKey.ownerEmail}::${e.spotKey.name}::${e.spotKey.address}`
        )!;

        const created = await tx.event.create({
          data: {
            userId,
            spotId,
            title: e.title,
            description: e.description,
            category: e.category as Category,
            address: e.address,
            neighborhood: e.neighborhood,
            latitude: e.latitude,
            longitude: e.longitude,
            startTime: new Date(e.startTime),
            endTime: e.endTime ? new Date(e.endTime) : null,
            saveCount: e.saveCount,
          },
        });
        createdEvents++;

        for (const m of e.media) {
          await tx.mediaItem.create({
            data: {
              eventId: created.id,
              url: m.url,
              type: m.type as MediaType,
              order: m.order,
            },
          });
          createdMedia++;
        }

        if ((i + 1) % 25 === 0) {
          console.log(`   ${i + 1}/${events.length} events imported`);
        }
      }
    },
    { timeout: 5 * 60 * 1000 }
  );

  console.log(`\n✅ Imported ${createdEvents} events / ${createdMedia} media items`);

  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error(e);
  await prisma.$disconnect();
  process.exit(1);
});
