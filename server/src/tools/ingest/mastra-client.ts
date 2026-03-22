/* istanbul ignore file */
import { config } from '../../config/index.js';
import { createLogger } from '../../services/logger.js';
import { normalizeMastraApiBase } from '../../utils/mastraUrl.js';

const logger = createLogger({ component: 'mastra-client' });

export type IngestWorkflowInput = {
  inputType: 'telegram_link' | 'telegram_text' | 'batch_yaml';
  rawInput: string;
  contextNote: string | null;
};

const mastraBase = (): string =>
  normalizeMastraApiBase(config.MASTRA_API_URL ?? 'http://127.0.0.1:4111');

const headers = (): Record<string, string> => {
  const h: Record<string, string> = {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  };
  if (config.MASTRA_SERVER_TOKEN) {
    h['Authorization'] = `Bearer ${config.MASTRA_SERVER_TOKEN}`;
  }
  return h;
};

/**
 * Runs ingest workflow until suspend, success, failure, or bail. Uses Mastra start-async route
 * (handler awaits until first terminal state for that run).
 */
export async function runIngestWorkflow(input: IngestWorkflowInput): Promise<unknown> {
  const url = `${mastraBase()}/api/workflows/ingest/start-async`;
  const res = await fetch(url, {
    method: 'POST',
    headers: headers(),
    body: JSON.stringify({ inputData: input }),
    signal: AbortSignal.timeout(300_000),
  });

  const text = await res.text();
  let json: unknown;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { parseError: true, raw: text };
  }

  if (!res.ok) {
    logger.warn({ status: res.status, json }, 'Mastra ingest workflow HTTP error');
    throw new Error(`Mastra workflow failed: ${res.status}`);
  }

  return json;
}

export function extractDraftNameFromMastraResult(result: unknown): string | null {
  if (!result || typeof result !== 'object') {
    return null;
  }
  const r = result as Record<string, unknown>;
  if (r['status'] === 'suspended') {
    const sp = r['suspendPayload'] as Record<string, unknown> | undefined;
    const d = sp?.['draft'] as Record<string, unknown> | undefined;
    if (typeof d?.['name'] === 'string') {
      return d['name'];
    }
    const steps = r['steps'] as
      | Record<string, { payload?: { draft?: { name?: string } } }>
      | undefined;
    const hr = steps?.['human-review'];
    const name = hr?.payload?.draft?.name;
    if (typeof name === 'string') {
      return name;
    }
  }
  if (r['status'] === 'success') {
    const res = r['result'] as Record<string, unknown> | undefined;
    if (res && typeof res === 'object' && typeof res['portalId'] === 'string') {
      return 'Published';
    }
  }
  return null;
}
