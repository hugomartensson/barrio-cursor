import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';
import type { ApiErrorResponse } from '../types/index.js';

interface ValidationSchemas {
  body?: ZodSchema;
  query?: ZodSchema;
  params?: ZodSchema;
}

type ValidateRequestHandler = (
  req: Request,
  res: Response<ApiErrorResponse>,
  next: NextFunction
) => void;

export const validateRequest = (schemas: ValidationSchemas): ValidateRequestHandler => {
  return (req: Request, res: Response<ApiErrorResponse>, next: NextFunction): void => {
    const errors: Record<string, string> = {};

    try {
      if (schemas.body) {
        // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
        req.body = schemas.body.parse(req.body);
      }
      if (schemas.query) {
        req.query = schemas.query.parse(req.query) as typeof req.query;
      }
      if (schemas.params) {
        req.params = schemas.params.parse(req.params) as typeof req.params;
      }
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        err.errors.forEach((e) => {
          const path = e.path.join('.');
          errors[path] = e.message;
        });

        res.status(400).json({
          error: {
            code: 'VALIDATION_ERROR',
            message: 'Invalid request data',
            details: errors,
          },
        });
        return;
      }
      next(err);
    }
  };
};
