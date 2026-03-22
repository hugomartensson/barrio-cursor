import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { config } from '../config/index.js';
import { logger } from '../services/logger.js';
import type { AuthenticatedRequest } from '../types/index.js';
import { normalizeMastraApiBase } from '../utils/mastraUrl.js';

async function proxyToMastra(req: Request, res: Response): Promise<void> {
  const user = (req as AuthenticatedRequest).user;
  if (!user) {
    res
      .status(401)
      .json({ error: { code: 'UNAUTHORIZED', message: 'Authentication required' } });
    return;
  }

  const mastraBase = normalizeMastraApiBase(
    config.MASTRA_API_URL ?? 'http://127.0.0.1:4111'
  );
  const targetUrl = `${mastraBase}${req.originalUrl}`;

  const headers: Record<string, string> = {
    Accept: req.headers.accept ?? 'application/json',
  };
  if (config.MASTRA_SERVER_TOKEN) {
    headers['Authorization'] = `Bearer ${config.MASTRA_SERVER_TOKEN}`;
  }
  if (req.headers['content-type']) {
    headers['Content-Type'] = req.headers['content-type'];
  }

  const noBody =
    req.method === 'GET' || req.method === 'HEAD' || req.method === 'OPTIONS';
  const body = noBody ? undefined : JSON.stringify(req.body ?? {});
  if (noBody) {
    delete headers['Content-Type'];
  }

  const mastraRes = await fetch(targetUrl, {
    method: req.method,
    headers,
    body,
    signal: AbortSignal.timeout(300_000),
  });

  const text = await mastraRes.text();
  let json: unknown;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }
  res.status(mastraRes.status).json(json);
}

/**
 * Forward /api/workflows/* to the Mastra service. Keeps the dashboard on same origin
 * and attaches a shared secret so Mastra can authenticate server-to-server calls.
 */
export const mastraWorkflowProxy: RequestHandler = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  void proxyToMastra(req, res).catch((error) => {
    logger.error({ error, url: req.originalUrl }, 'Mastra workflow proxy failed');
    if (!res.headersSent) {
      res.status(502).json({
        error: { code: 'MASTRA_PROXY_ERROR', message: 'Could not reach Mastra service' },
      });
    } else {
      next(error);
    }
  });
};
