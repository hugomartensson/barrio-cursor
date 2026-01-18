import { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';
import type { RequestWithId } from '../types/index.js';

/**
 * Request ID middleware
 * Adds a unique request ID to each request for tracing
 */
export const requestIdMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const requestWithId = req as RequestWithId;
  // Generate or use existing request ID
  const requestId = (req.headers['x-request-id'] as string) || randomUUID();

  // Add to request object
  requestWithId.id = requestId;

  // Add to response headers
  res.setHeader('X-Request-ID', requestId);

  next();
};
