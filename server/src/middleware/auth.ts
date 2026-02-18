import { Request, Response, NextFunction } from 'express';
import { supabaseAdmin } from '../services/supabase.js';
import { syncUserToDatabase } from '../services/userSync.js';
import { ApiError } from '../utils/ApiError.js';
import { createLogger } from '../services/logger.js';
import type {
  ApiErrorResponse,
  AuthenticatedRequest,
  RequestWithId,
} from '../types/index.js';

const logger = createLogger({ component: 'auth-middleware' });

/**
 * Middleware to verify Supabase JWT token
 * Extracts user info and attaches to request
 */
export const requireAuth = async (
  req: Request,
  res: Response<ApiErrorResponse>,
  next: NextFunction
): Promise<void> => {
  const requestWithId = req as RequestWithId;
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    res
      .status(401)
      .json({ error: { code: 'UNAUTHORIZED', message: 'Missing authorization' } });
    return;
  }

  const token = authHeader.substring(7);

  try {
    // Verify token with Supabase admin client
    const {
      data: { user },
      error,
    } = await supabaseAdmin.auth.getUser(token);

    if (error) {
      logger.warn(
        { error: error.message, requestId: requestWithId.id || 'unknown' },
        'Auth error: Invalid token'
      );
      res.status(401).json({
        error: { code: 'UNAUTHORIZED', message: `Invalid token: ${error.message}` },
      });
      return;
    }

    if (!user) {
      logger.warn(
        { requestId: requestWithId.id || 'unknown' },
        'No user returned from Supabase'
      );
      res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Invalid token' } });
      return;
    }

    // Ensure user exists in local DB (handles token restore, DB reset, etc.)
    const email = user.email ?? '';
    const name =
      (user.user_metadata?.['name'] as string) ?? email.split('@')[0] ?? 'User';
    try {
      await syncUserToDatabase(user.id, email, name);
    } catch (syncErr) {
      logger.error(
        {
          error: syncErr,
          userId: user.id,
          requestId: requestWithId.id || 'unknown',
        },
        'Failed to sync user to database'
      );
      res.status(503).json({
        error: {
          code: 'SERVICE_UNAVAILABLE',
          message: 'Unable to sync user session. Please try logging in again.',
        },
      });
      return;
    }

    (req as AuthenticatedRequest).user = {
      userId: user.id,
      email,
    };

    next();
  } catch (err) {
    logger.error(
      { error: err, requestId: requestWithId.id || 'unknown' },
      'Auth catch error'
    );
    if (err instanceof ApiError) {
      res
        .status(err.statusCode)
        .json({ error: { code: err.code, message: err.message } });
      return;
    }
    next(err);
  }
};
