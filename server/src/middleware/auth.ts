import { Request, Response, NextFunction } from 'express';
import { supabaseAdmin } from '../services/supabase.js';
import { ApiError } from '../utils/ApiError.js';
import type { ApiErrorResponse, AuthenticatedRequest } from '../types/index.js';

/**
 * Middleware to verify Supabase JWT token
 * Extracts user info and attaches to request
 */
export const requireAuth = async (
  req: Request,
  res: Response<ApiErrorResponse>,
  next: NextFunction
): Promise<void> => {
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
    const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);

    if (error) {
      console.error('Auth error:', error.message);
      res
        .status(401)
        .json({ error: { code: 'UNAUTHORIZED', message: `Invalid token: ${error.message}` } });
      return;
    }
    
    if (!user) {
      console.error('No user returned from Supabase');
      res
        .status(401)
        .json({ error: { code: 'UNAUTHORIZED', message: 'Invalid token' } });
      return;
    }

    (req as AuthenticatedRequest).user = {
      userId: user.id,
      email: user.email ?? '',
    };

    next();
  } catch (err) {
    console.error('Auth catch error:', err);
    if (err instanceof ApiError) {
      res
        .status(err.statusCode)
        .json({ error: { code: err.code, message: err.message } });
      return;
    }
    next(err);
  }
};
