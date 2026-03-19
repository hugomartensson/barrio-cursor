/* istanbul ignore file */
import fs from 'node:fs/promises';
import YAML from 'yaml';
import { ItemType } from '@prisma/client';
import { detectSourceType } from './source-detect.js';
import { fetchGooglePlace } from './fetchers/google-places.js';
import { fetchInstagramPost } from './fetchers/instagram.js';
import { fetchWebsite } from './fetchers/website.js';
import { extractDraftFields } from './llm-mapper.js';
import { publisher } from './publisher.js';

type BatchItem = {
  url?: string;
  manual?: Record<string, unknown>;
  override?: Record<string, unknown>;
};

type BatchFile = {
  collection?: { name: string; description?: string };
  items: BatchItem[];
};

const main = async (): Promise<void> => {
  const yamlPath = process.argv[2];
  if (!yamlPath) {
    throw new Error('Usage: npm run batch -- ./path/to/file.yaml');
  }

  const fileContent = await fs.readFile(yamlPath, 'utf8');
  const parsed = YAML.parse(fileContent) as BatchFile;
  if (!parsed.items?.length) {
    throw new Error('YAML file has no items');
  }

  let collectionId: string | null = null;
  if (parsed.collection) {
    collectionId = await publisher.createCollection(
      parsed.collection.name,
      parsed.collection.description
    );
  }

  let published = 0;
  for (const item of parsed.items) {
    let payload = item.manual ?? {};
    if (item.url) {
      const sourceType = detectSourceType(item.url);
      const fetched =
        sourceType === 'google_maps'
          ? await fetchGooglePlace(item.url)
          : sourceType === 'instagram_post'
            ? await fetchInstagramPost(item.url)
            : await fetchWebsite(item.url);

      const mapped = await extractDraftFields({
        rawText: fetched.rawText,
        sourceUrl: item.url,
        partialFields: fetched,
      });
      payload = { ...mapped.fields };
    }

    payload = { ...payload, ...(item.override ?? {}) };

    const itemType = payload['itemType'] as ItemType;
    if (
      !itemType ||
      !payload['name'] ||
      !payload['description'] ||
      !payload['category'] ||
      !payload['address']
    ) {
      // eslint-disable-next-line no-console
      console.log('Skipping item due to missing required fields');
      continue;
    }

    const portalId = await publisher.publishDraft({
      itemType,
      name: String(payload['name']),
      description: String(payload['description']),
      category: String(payload['category']),
      address: String(payload['address']),
      neighborhood: (payload['neighborhood'] as string | undefined) ?? null,
      tags: (payload['tags'] as string[] | undefined) ?? [],
      imageUrl: (payload['imageUrl'] as string | undefined) ?? null,
      startTime: (payload['startTime'] as string | undefined) ?? null,
      endTime: (payload['endTime'] as string | undefined) ?? null,
      collectionId,
    });
    published += 1;
    const publishedName =
      typeof payload['name'] === 'string' ? payload['name'] : 'Unnamed';
    // eslint-disable-next-line no-console
    console.log(`Published "${publishedName}" (${itemType}) -> ${portalId}`);
  }

  // eslint-disable-next-line no-console
  console.log(`Published ${published}/${parsed.items.length} items`);
};

void main();
