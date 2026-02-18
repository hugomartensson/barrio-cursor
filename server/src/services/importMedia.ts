import { uploadFile, type UploadResult } from './media.js';
import { logger } from './logger.js';

/**
 * Download an image from an external URL and re-upload it to Supabase Storage.
 * Returns the Supabase public URL. This ensures we don't depend on external CDN
 * URLs which may expire (especially Instagram/Facebook).
 */
export async function downloadAndUploadMedia(
  externalUrl: string,
  userId: string
): Promise<UploadResult> {
  logger.info({ externalUrl }, 'Downloading external media');

  const response = await fetch(externalUrl, {
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      Accept: 'image/*,video/*,*/*',
    },
    redirect: 'follow',
  });

  if (!response.ok) {
    throw new Error(
      `Failed to download media: ${response.status} ${response.statusText} from ${externalUrl}`
    );
  }

  const contentType = response.headers.get('content-type') ?? 'image/jpeg';
  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);

  if (buffer.length === 0) {
    throw new Error(`Downloaded empty file from ${externalUrl}`);
  }

  // Normalize content type — some servers return charset or other params
  const mimeType = normalizeMimeType(contentType);

  logger.info(
    { externalUrl, mimeType, sizeBytes: buffer.length },
    'Media downloaded, uploading to Supabase Storage'
  );

  const result = await uploadFile(userId, buffer, mimeType);

  logger.info(
    { externalUrl, supabaseUrl: result.url, type: result.type },
    'Media re-uploaded to Supabase Storage'
  );

  return result;
}

/**
 * Attempt to download and re-upload multiple media URLs.
 * Returns successful uploads and a list of URLs that failed.
 */
export async function downloadAndUploadMultipleMedia(
  externalUrls: string[],
  userId: string
): Promise<{
  uploaded: UploadResult[];
  failed: { url: string; error: string }[];
}> {
  const uploaded: UploadResult[] = [];
  const failed: { url: string; error: string }[] = [];

  for (const url of externalUrls) {
    try {
      const result = await downloadAndUploadMedia(url, userId);
      uploaded.push(result);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      logger.warn(
        { url, error: message },
        'Failed to download media, will need manual upload'
      );
      failed.push({ url, error: message });
    }
  }

  return { uploaded, failed };
}

/**
 * Normalize MIME type from response headers.
 * Strips charset/parameters and maps common types.
 */
function normalizeMimeType(contentType: string): string {
  // Strip parameters (e.g. "image/jpeg; charset=utf-8" -> "image/jpeg")
  const base = contentType.split(';')[0]?.trim().toLowerCase() ?? 'image/jpeg';

  // Map common edge cases
  const mimeMap: Record<string, string> = {
    'image/jpg': 'image/jpeg',
    'image/pjpeg': 'image/jpeg',
    'image/x-png': 'image/png',
    'binary/octet-stream': 'image/jpeg',
    'application/octet-stream': 'image/jpeg',
  };

  return mimeMap[base] ?? base;
}
