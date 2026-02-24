import { supabaseAdmin, STORAGE_BUCKET } from './supabase.js';
import { ApiError } from '../utils/ApiError.js';
import { logger } from './logger.js';
import { randomUUID } from 'crypto';

const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
const MAX_IMAGE_SIZE = 10 * 1024 * 1024; // 10 MB

export interface UploadResult {
  url: string;
  type: 'photo';
}

export const validateFile = (mimeType: string, size: number): void => {
  if (!ALLOWED_IMAGE_TYPES.includes(mimeType)) {
    throw ApiError.badRequest(`Invalid file type: ${mimeType}`, {
      allowed: ALLOWED_IMAGE_TYPES,
    });
  }

  if (size > MAX_IMAGE_SIZE) {
    const maxMB = MAX_IMAGE_SIZE / (1024 * 1024);
    throw ApiError.badRequest(`File too large. Maximum size: ${maxMB} MB`);
  }
};

export const generateFilePath = (userId: string, mimeType: string): string => {
  const extension = mimeType.split('/')[1] ?? 'bin';
  const filename = `${randomUUID()}.${extension}`;
  return `${userId}/${filename}`;
};

export const uploadFile = async (
  userId: string,
  fileBuffer: Buffer,
  mimeType: string
): Promise<UploadResult> => {
  validateFile(mimeType, fileBuffer.length);

  const filePath = generateFilePath(userId, mimeType);

  const { data, error } = await supabaseAdmin.storage
    .from(STORAGE_BUCKET)
    .upload(filePath, fileBuffer, {
      contentType: mimeType,
      upsert: false,
    });

  if (error) {
    const errorDetails = {
      message: error.message,
      statusCode: (error as unknown as { statusCode?: number }).statusCode,
      error: (error as unknown as { error?: string }).error,
    };
    throw new ApiError(
      500,
      'INTERNAL_ERROR',
      `Upload failed: ${error.message}`,
      errorDetails
    );
  }

  if (!data) {
    throw ApiError.internal('Upload succeeded but no data returned');
  }

  const {
    data: { publicUrl },
  } = supabaseAdmin.storage.from(STORAGE_BUCKET).getPublicUrl(filePath);

  return {
    url: publicUrl,
    type: 'photo',
  };
};

export const deleteFile = async (fileUrl: string): Promise<void> => {
  const urlParts = fileUrl.split(`${STORAGE_BUCKET}/`);
  const filePath = urlParts[1];

  if (!filePath) {
    return;
  }

  const { error } = await supabaseAdmin.storage.from(STORAGE_BUCKET).remove([filePath]);

  if (error) {
    logger.warn({ fileUrl, error: error.message }, 'Failed to delete file from storage');
  }
};

export const createSignedUploadUrl = async (
  userId: string,
  mimeType: string
): Promise<{ uploadUrl: string; filePath: string }> => {
  validateFile(mimeType, 0);

  const filePath = generateFilePath(userId, mimeType);

  const { data, error } = await supabaseAdmin.storage
    .from(STORAGE_BUCKET)
    .createSignedUploadUrl(filePath, {
      upsert: false,
    });

  if (error || !data) {
    logger.error({ error, filePath, mimeType }, 'Failed to create signed upload URL');
    throw ApiError.internal('Failed to create upload URL');
  }

  return {
    uploadUrl: data.signedUrl,
    filePath,
  };
};

export const getPublicUrl = (filePath: string): string => {
  const {
    data: { publicUrl },
  } = supabaseAdmin.storage.from(STORAGE_BUCKET).getPublicUrl(filePath);

  return publicUrl;
};
