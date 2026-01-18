import { Router, Request, Response } from 'express';
import { supabaseAdmin } from '../services/supabase.js';
import { syncUserToDatabase } from '../services/userSync.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { signupSchema, loginSchema, resetPasswordSchema } from '../schemas/auth.js';
import type { SignupInput, LoginInput, ResetPasswordInput } from '../schemas/auth.js';
import type { ApiErrorResponse, RequestWithId } from '../types/index.js';
import { createLogger } from '../services/logger.js';

const logger = createLogger({ component: 'auth-routes' });

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
      const requestId = (req as RequestWithId).id;
      const { email, password, name } = req.body;

      logger.info(
        {
          requestId,
          email,
          userAgent: req.headers['user-agent'],
          ip: req.ip,
        },
        'Signup request received'
      );

      // Set email redirect URL to our API endpoint (or disable if email confirmation not needed)
      // If email confirmation is enabled in Supabase, this URL will be used
      // For now, we'll set it to undefined to disable email confirmation redirects
      // If you need email confirmation, set this to your frontend URL
      logger.debug({ requestId, email }, 'Calling Supabase signUp');
      const supabaseStartTime = Date.now();
      const { data, error } = await supabaseAdmin.auth.signUp({
        email,
        password,
        options: {
          data: { name },
          emailRedirectTo: undefined, // Disable email redirects - we handle auth via API
        },
      });
      const supabaseDuration = Date.now() - supabaseStartTime;
      logger.debug(
        { requestId, email, duration: `${supabaseDuration}ms` },
        'Supabase signUp completed'
      );

      if (error) {
        const errorMessage = error.message || 'Unknown error';
        const errorLower = errorMessage.toLowerCase();

        // Check if it's a network/connection error to Supabase
        if (
          errorLower.includes('fetch failed') ||
          errorLower.includes('network') ||
          errorLower.includes('connection') ||
          errorLower.includes('econnrefused') ||
          errorLower.includes('timeout')
        ) {
          logger.error(
            {
              error: errorMessage,
              errorCode: (error as { code?: string })?.code,
              requestId: (req as RequestWithId).id,
              supabaseUrl: process.env['SUPABASE_URL'],
              endpoint: '/auth/signup',
            },
            'Supabase connection error - cannot reach authentication service'
          );
          res.status(503).json({
            error: {
              code: 'SERVICE_UNAVAILABLE',
              message: 'Unable to connect to authentication service (Supabase).',
              details: {
                issue: 'SUPABASE_CONNECTION_FAILED',
                supabaseUrl: process.env['SUPABASE_URL'] || 'not configured',
                suggestion:
                  'Check your network connection and verify Supabase is accessible. Run GET /api/health to check service status.',
              },
            },
          });
          return;
        }

        // Other Supabase errors (validation, user exists, etc.)
        logger.warn(
          {
            error: errorMessage,
            errorCode: (error as { code?: string })?.code,
            requestId: (req as RequestWithId).id,
            email: email,
          },
          'Supabase auth error'
        );
        res.status(400).json({
          error: {
            code: 'AUTH_ERROR',
            message: errorMessage,
            details: {
              issue: 'SUPABASE_AUTH_ERROR',
              suggestion:
                'Check if email is already registered or if there are validation issues.',
            },
          },
        });
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
      try {
        await syncUserToDatabase(data.user.id, data.user.email ?? '', userName);
      } catch (dbError) {
        // Log database sync error but don't fail the signup (user is created in Supabase)
        logger.error(
          {
            error: dbError instanceof Error ? dbError.message : String(dbError),
            userId: data.user.id,
            email: data.user.email,
            requestId: (req as RequestWithId).id,
          },
          'Failed to sync user to database after Supabase signup'
        );
        // Continue - user is created in Supabase, database sync can be retried
      }

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
  asyncHandler(async (req: Request, res: Response<AuthResponse | ApiErrorResponse>) => {
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
    const {
      data: { user },
    } = await supabaseAdmin.auth.getUser(data.session.access_token);

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
  })
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

      // Set redirect URL to our API endpoint (or your frontend URL)
      // For mobile apps, this might not be used, but it should match your Supabase dashboard settings
      const { error } = await supabaseAdmin.auth.resetPasswordForEmail(email, {
        redirectTo: undefined, // Disable redirect - we handle via API
      });
      if (error) {
        // Note: Don't log password reset errors to avoid leaking email existence
        // Supabase handles this gracefully
      }

      // Always return success to prevent email enumeration
      res.json({
        data: { message: 'If an account exists, a password reset email has been sent' },
      });
    }
  )
);

export default router;
