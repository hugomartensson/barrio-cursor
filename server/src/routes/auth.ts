import { Router, Request, Response } from 'express';
import { supabaseAdmin } from '../services/supabase.js';
import { syncUserToDatabase } from '../services/userSync.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { signupSchema, loginSchema, resetPasswordSchema } from '../schemas/auth.js';
import type { SignupInput, LoginInput, ResetPasswordInput } from '../schemas/auth.js';
import type { ApiErrorResponse } from '../types/index.js';

const router = Router();

interface AuthResponse {
  data: {
    user: { id: string; email: string; name: string };
    token: string;
    refreshToken?: string;
    message?: string;
  };
}

interface MessageResponse {
  data: { message: string };
}

type SignupRequest = Request<object, AuthResponse | ApiErrorResponse, SignupInput>;
type LoginRequest = Request<object, AuthResponse | ApiErrorResponse, LoginInput>;
type ResetRequest = Request<
  object,
  MessageResponse | ApiErrorResponse,
  ResetPasswordInput
>;

/**
 * POST /auth/signup - Create a new user account
 */
router.post(
  '/signup',
  validateRequest({ body: signupSchema }),
  asyncHandler(
    async (req: SignupRequest, res: Response<AuthResponse | ApiErrorResponse>) => {
      const { email, password, name } = req.body;

      const { data, error } = await supabaseAdmin.auth.signUp({
        email,
        password,
        options: { data: { name }, emailRedirectTo: undefined },
      });

      if (error) {
        res.status(400).json({ error: { code: 'AUTH_ERROR', message: error.message } });
        return;
      }

      // If no session, email confirmation might be enabled
      if (!data.user) {
        res
          .status(400)
          .json({ error: { code: 'AUTH_ERROR', message: 'Failed to create user' } });
        return;
      }

      // Handle case where email confirmation is enabled (no session returned)
      if (!data.session) {
        res.status(201).json({
          data: {
            user: {
              id: data.user.id,
              email: data.user.email ?? '',
              name: (data.user.user_metadata?.['name'] as string) ?? name,
            },
            token: '', // No token until email confirmed
            message: 'Please check your email to confirm your account',
          },
        });
        return;
      }

      // Sync user to local database
      const userName = (data.user.user_metadata?.['name'] as string) ?? name;
      await syncUserToDatabase(data.user.id, data.user.email ?? '', userName);

      res.status(201).json({
        data: {
          user: { id: data.user.id, email: data.user.email ?? '', name: userName },
          token: data.session.access_token,
          refreshToken: data.session.refresh_token,
        },
      });
    }
  )
);

/**
 * POST /auth/login - Sign in with email and password
 */
router.post(
  '/login',
  validateRequest({ body: loginSchema }),
  asyncHandler(
    async (req: LoginRequest, res: Response<AuthResponse | ApiErrorResponse>) => {
      const { email, password } = req.body;

      const { data, error } = await supabaseAdmin.auth.signInWithPassword({
        email,
        password,
      });

      if (error || !data.user || !data.session) {
        res
          .status(401)
          .json({ error: { code: 'AUTH_ERROR', message: 'Invalid email or password' } });
        return;
      }

      // Sync user to local database on login
      const userName = (data.user.user_metadata?.['name'] as string) ?? '';
      await syncUserToDatabase(data.user.id, data.user.email ?? '', userName);

      res.json({
        data: {
          user: { id: data.user.id, email: data.user.email ?? '', name: userName },
          token: data.session.access_token,
          refreshToken: data.session.refresh_token,
        },
      });
    }
  )
);

/**
 * POST /auth/refresh - Refresh access token using refresh token
 */
router.post(
  '/refresh',
  asyncHandler(
    async (req: Request, res: Response<AuthResponse | ApiErrorResponse>) => {
      const { refreshToken } = req.body;

      if (!refreshToken) {
        res
          .status(400)
          .json({ error: { code: 'AUTH_ERROR', message: 'Refresh token required' } });
        return;
      }

      const { data, error } = await supabaseAdmin.auth.refreshSession({
        refresh_token: refreshToken,
      });

      if (error || !data.session) {
        res
          .status(401)
          .json({ error: { code: 'AUTH_ERROR', message: 'Invalid refresh token' } });
        return;
      }

      // Get user info
      const { data: { user } } = await supabaseAdmin.auth.getUser(data.session.access_token);

      if (!user) {
        res
          .status(401)
          .json({ error: { code: 'AUTH_ERROR', message: 'Failed to get user' } });
        return;
      }

      const userName = (user.user_metadata?.['name'] as string) ?? '';

      res.json({
        data: {
          user: { id: user.id, email: user.email ?? '', name: userName },
          token: data.session.access_token,
          refreshToken: data.session.refresh_token,
        },
      });
    }
  )
);

/**
 * POST /auth/reset-password - Send password reset email
 */
router.post(
  '/reset-password',
  validateRequest({ body: resetPasswordSchema }),
  asyncHandler(
    async (req: ResetRequest, res: Response<MessageResponse | ApiErrorResponse>) => {
      const { email } = req.body;

      const { error } = await supabaseAdmin.auth.resetPasswordForEmail(email);
      if (error) {
        console.error('Password reset error:', error.message);
      }

      // Always return success to prevent email enumeration
      res.json({
        data: { message: 'If an account exists, a password reset email has been sent' },
      });
    }
  )
);

export default router;
