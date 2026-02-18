import { Router, Request, Response } from 'express';
import { networkInterfaces } from 'os';
import { supabaseAdmin } from '../services/supabase.js';
import { prisma } from '../services/prisma.js';
import { createLogger } from '../services/logger.js';
import { config } from '../config/index.js';

const router = Router();
const logger = createLogger({ component: 'health' });

interface HealthResponse {
  status: string;
  timestamp: string;
  uptime: number;
  environment: string;
  services: {
    database: {
      status: 'healthy' | 'unhealthy';
      error?: string;
    };
    supabase: {
      status: 'healthy' | 'unhealthy';
      error?: string;
      url?: string;
    };
  };
}

/**
 * GET /api/health - Health check with service connectivity tests
 */
router.get('/', async (_req: Request, res: Response<HealthResponse>): Promise<void> => {
  const services: HealthResponse['services'] = {
    database: { status: 'unhealthy' },
    supabase: { status: 'unhealthy' },
  };

  // Test database connectivity
  try {
    await prisma.$queryRaw`SELECT 1`;
    services.database = { status: 'healthy' };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    services.database = {
      status: 'unhealthy',
      error: errorMessage,
    };
    logger.error({ error: errorMessage }, 'Database health check failed');
  }

  // Test Supabase connectivity
  try {
    // Simple test: try to get the auth service (this will fail if Supabase is unreachable)
    const supabaseUrl = process.env['SUPABASE_URL'] || 'not configured';
    // Test by attempting a lightweight operation
    const { error } = await supabaseAdmin.auth.admin.listUsers({ page: 1, perPage: 1 });

    if (error && error.message?.toLowerCase().includes('fetch failed')) {
      services.supabase = {
        status: 'unhealthy',
        error: `Connection failed: ${error.message}`,
        url: supabaseUrl,
      };
    } else {
      // Even if there's an error (like permission), if we got a response, Supabase is reachable
      services.supabase = {
        status: 'healthy',
        url: supabaseUrl,
      };
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    services.supabase = {
      status: 'unhealthy',
      error: errorMessage,
      url: process.env['SUPABASE_URL'] || 'not configured',
    };
    logger.error({ error: errorMessage }, 'Supabase health check failed');
  }

  const overallStatus =
    services.database.status === 'healthy' && services.supabase.status === 'healthy'
      ? 'healthy'
      : 'degraded';

  res.json({
    status: overallStatus,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env['NODE_ENV'] || 'development',
    services,
  });
});

/**
 * GET /api/health/network - Get server's network IP addresses
 * Helps iOS app auto-detect the correct IP to connect to
 */
router.get('/network', (_req: Request, res: Response): void => {
  const interfaces = networkInterfaces();
  const ips: string[] = [];

  // Collect all IPv4 addresses (excluding localhost)
  for (const name of Object.keys(interfaces)) {
    const nets = interfaces[name];
    if (!nets) {
      continue;
    }

    for (const net of nets) {
      // Skip internal (loopback) and non-IPv4 addresses
      if (net.family === 'IPv4' && !net.internal) {
        ips.push(net.address);
      }
    }
  }

  // Also include common localhost variants for simulator
  const localhostIPs = ['127.0.0.1', 'localhost'];

  res.json({
    serverIPs: ips,
    localhostIPs,
    port: config.PORT,
    baseURL: `http://localhost:${config.PORT}/api`,
    suggestedURLs: [
      ...localhostIPs.map((ip) => `http://${ip}:${config.PORT}/api`),
      ...ips.map((ip) => `http://${ip}:${config.PORT}/api`),
    ],
  });
});
export default router;
