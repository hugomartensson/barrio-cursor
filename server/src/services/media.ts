import { supabaseAdmin, STORAGE_BUCKET } from './supabase.js';
import { ApiError } from '../utils/ApiError.js';
import { randomUUID } from 'crypto';

// Allowed MIME types
const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
const ALLOWED_VIDEO_TYPES = ['video/mp4', 'video/quicktime', 'video/webm'];
const ALLOWED_TYPES = [...ALLOWED_IMAGE_TYPES, ...ALLOWED_VIDEO_TYPES];

// Size limits from PRD
const MAX_IMAGE_SIZE = 10 * 1024 * 1024; // 10 MB
const MAX_VIDEO_SIZE = 50 * 1024 * 1024; // 50 MB

// Video duration limit from PRD Section 7.4
const MAX_VIDEO_DURATION_SECONDS = 15;

export interface UploadResult {
  url: string;
  type: 'photo' | 'video';
}

/**
 * Validate file before upload
 */
export const validateFile = (mimeType: string, size: number): void => {
  if (!ALLOWED_TYPES.includes(mimeType)) {
    throw ApiError.badRequest(`Invalid file type: ${mimeType}`, {
      allowed: ALLOWED_TYPES,
    });
  }

  const isVideo = ALLOWED_VIDEO_TYPES.includes(mimeType);
  const maxSize = isVideo ? MAX_VIDEO_SIZE : MAX_IMAGE_SIZE;

  if (size > maxSize) {
    const maxMB = maxSize / (1024 * 1024);
    throw ApiError.badRequest(`File too large. Maximum size: ${maxMB} MB`);
  }
};

/**
 * Validate video duration
 * Per PRD Section 7.4: Videos must be 15 seconds or less
 */
export const validateVideoDuration = (durationSeconds: number): void => {
  if (durationSeconds > MAX_VIDEO_DURATION_SECONDS) {
    throw ApiError.unprocessableEntity(
      `Videos must be 15 seconds or less. This video is ${Math.ceil(durationSeconds)} seconds.`
    );
  }
};

/**
 * Generate a unique file path for storage
 */
export const generateFilePath = (userId: string, mimeType: string): string => {
  const extension = mimeType.split('/')[1] ?? 'bin';
  const filename = `${randomUUID()}.${extension}`;
  return `${userId}/${filename}`;
};

/**
 * Get media type from MIME type
 */
export const getMediaType = (mimeType: string): 'photo' | 'video' => {
  return ALLOWED_VIDEO_TYPES.includes(mimeType) ? 'video' : 'photo';
};

/**
 * Upload a file to Supabase Storage
 */
export const uploadFile = async (
  userId: string,
  fileBuffer: Buffer,
  mimeType: string
): Promise<UploadResult> => {
  validateFile(mimeType, fileBuffer.length);

  const filePath = generateFilePath(userId, mimeType);
  const mediaType = getMediaType(mimeType);

  const { error } = await supabaseAdmin.storage
    .from(STORAGE_BUCKET)
    .upload(filePath, fileBuffer, {
      contentType: mimeType,
      upsert: false,
    });

  if (error) {
    throw ApiError.internal(`Upload failed: ${error.message}`);
  }

  // Get public URL
  const {
    data: { publicUrl },
  } = supabaseAdmin.storage.from(STORAGE_BUCKET).getPublicUrl(filePath);

  return {
    url: publicUrl,
    type: mediaType,
  };
};

/**
 * Delete a file from Supabase Storage
 */
export const deleteFile = async (fileUrl: string): Promise<void> => {
  // Extract path from URL
  const urlParts = fileUrl.split(`${STORAGE_BUCKET}/`);
  const filePath = urlParts[1];

  if (!filePath) {
    return; // Invalid URL, nothing to delete
  }

  const { error } = await supabaseAdmin.storage.from(STORAGE_BUCKET).remove([filePath]);

  if (error) {
    console.error('Failed to delete file:', error.message);
  }
};

/**
 * Generate a signed upload URL for client-side uploads
 * This allows the iOS app to upload directly to Supabase
 */
export const createSignedUploadUrl = async (
  userId: string,
  mimeType: string
): Promise<{ uploadUrl: string; filePath: string }> => {
  validateFile(mimeType, 0); // Validate type only, size checked client-side

  const filePath = generateFilePath(userId, mimeType);

  const { data, error } = await supabaseAdmin.storage
    .from(STORAGE_BUCKET)
    .createSignedUploadUrl(filePath);

  if (error || !data) {
    throw ApiError.internal('Failed to create upload URL');
  }

  return {
    uploadUrl: data.signedUrl,
    filePath,
  };
};

/**
 * Get public URL for a file path
 */
export const getPublicUrl = (filePath: string): string => {
  const {
    data: { publicUrl },
  } = supabaseAdmin.storage.from(STORAGE_BUCKET).getPublicUrl(filePath);

  return publicUrl;
};


