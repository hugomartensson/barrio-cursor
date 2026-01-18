import * as pinoModule from 'pino';
import type { Logger } from 'pino';
import { config } from '../config/index.js';

/**
 * Structured logging service using pino
 * Per guidelines: Structured logging required before TestFlight
 * Replaces previous console-based logging with production-ready structured logs
 */

// Configure log level based on environment
const logLevel = config.NODE_ENV === 'production' ? 'info' : 'debug';

// Create base logger - handle default export for ES modules
const pino = ((pinoModule as unknown as { default?: typeof pinoModule }).default ||
  pinoModule) as typeof pinoModule & ((...args: unknown[]) => Logger);
const baseLogger = pino({
  level: logLevel,
  transport:
    config.NODE_ENV === 'development'
      ? {
          target: 'pino-pretty',
          options: {
            colorize: true,
            translateTime: 'HH:MM:ss',
            ignore: 'pid,hostname',
          },
        }
      : undefined,
  formatters: {
    level: (label: string) => {
      return { level: label };
    },
  },
});

/**
 * Create a child logger with context
 */
export function createLogger(context?: Record<string, unknown>): Logger {
  return context ? baseLogger.child(context) : baseLogger;
}

/**
 * Default logger instance
 */
export const logger = createLogger();
