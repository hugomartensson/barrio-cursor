import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const BUCKET = process.env.SUPABASE_INGEST_BUCKET ?? 'ingest-images';

let supabase: SupabaseClient | null = null;

const getClient = (): SupabaseClient | null => {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_KEY;
  if (!url || !key) return null;
  if (!supabase) {
    supabase = createClient(url, key);
  }
  return supabase;
};

/**
 * Download remote image and upload to Supabase Storage (ingest bucket). Returns public URL.
 */
export async function downloadAndUploadIngestImage(
  imageUrl: string,
  filenameHint?: string,
): Promise<string> {
  const client = getClient();
  if (!client) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_KEY are required for image upload');
  }

  const imageRes = await fetch(imageUrl, {
    signal: AbortSignal.timeout(30_000),
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    },
  });
  if (!imageRes.ok) {
    throw new Error(`Failed to download image: ${imageRes.status}`);
  }

  const contentType = imageRes.headers.get('content-type') ?? 'image/jpeg';
  const ext =
    contentType.includes('png') ? 'png' : contentType.includes('webp') ? 'webp' : 'jpg';
  const buffer = Buffer.from(await imageRes.arrayBuffer());
  const name =
    (filenameHint?.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 80) || 'cover') +
    `-${Date.now()}.${ext}`;
  const path = `ingest/${name}`;

  const { error } = await client.storage.from(BUCKET).upload(path, buffer, {
    contentType,
    upsert: true,
  });
  if (error) {
    throw new Error(`Supabase upload failed: ${error.message}`);
  }

  const { data: pub } = client.storage.from(BUCKET).getPublicUrl(path);
  if (!pub?.publicUrl) {
    throw new Error('Supabase returned no public URL');
  }
  return pub.publicUrl;
}
