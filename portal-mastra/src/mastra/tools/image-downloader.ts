import { createTool } from '@mastra/core/tools';
import { z } from 'zod';
import { downloadAndUploadIngestImage } from '../lib/ingest-image.js';

export const imageDownloader = createTool({
  id: 'image-downloader',
  description:
    'Downloads an image from a public URL and uploads it to Supabase ingest storage. Returns a permanent public Supabase URL. Use at publish time.',
  inputSchema: z.object({
    imageUrl: z.string().url(),
    filename: z.string().optional(),
  }),
  outputSchema: z.object({
    supabaseUrl: z.string(),
  }),
  execute: async (inputData) => {
    const supabaseUrl = await downloadAndUploadIngestImage(
      inputData.imageUrl,
      inputData.filename,
    );
    return { supabaseUrl };
  },
});
