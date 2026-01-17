import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { ApiError } from '../utils/ApiError.js';
import { isProduction } from '../config/index.js';
import type { ApiErrorResponse } from '../types/index.js';

export const errorHandler = (
  err: Error,
  _req: Request,
  res: Response<ApiErrorResponse>,
  _next: NextFunction
): void => {
  // Log error in development
  if (!isProduction) {
    console.error('Error:', err);
  }

  // Handle known ApiError
  if (err instanceof ApiError) {
    res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        details: err.details,
      },
    });
    return;
  }

  // Handle Zod validation errors
  if (err instanceof ZodError) {
    const details = err.errors.reduce(
      (acc, e) => {
        const path = e.path.join('.');
        acc[path] = e.message;
        return acc;
      },
      {} as Record<string, string>
    );

    res.status(400).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid request data',
        details,
      },
    });
    return;
  }

  // Handle unknown errors - don't leak stack traces
  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: isProduction ? 'Internal server error' : err.message,
    },
  });
};

// 404 handler for unmatched routes
export const notFoundHandler = (
  req: Request,
  res: Response<ApiErrorResponse>,
  _next: NextFunction
): void => {
  res.status(404).json({
    error: {
      code: 'NOT_FOUND',
      message: `Route ${req.method} ${req.path} not found`,
    },
  });
};


