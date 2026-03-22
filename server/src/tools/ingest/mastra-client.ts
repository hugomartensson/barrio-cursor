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

/** Draft nested under human-review step (Mastra suspend shape). */
function draftFromSteps(r: Record<string, unknown>): { name?: string } | null {
  const steps = r['steps'] as
    | Record<
        string,
        {
          payload?: { draft?: { name?: string } };
          suspendPayload?: { draft?: { name?: string } };
        }
      >
    | undefined;
  const hr = steps?.['human-review'];
  const d = hr?.suspendPayload?.draft ?? hr?.payload?.draft;
  if (d && typeof d === 'object' && typeof (d as { name?: string }).name === 'string') {
    return d as { name: string };
  }
  const sp = r['suspendPayload'] as { draft?: { name?: string } } | undefined;
  if (typeof sp?.draft?.name === 'string') {
    return sp.draft as { name: string };
  }
  const p = r['payload'] as { draft?: { name?: string } } | undefined;
  if (typeof p?.draft?.name === 'string') {
    return p.draft as { name: string };
  }
  return null;
}

/**
 * Mastra may report human-in-the-loop as `suspended` or `waiting`; step payload may carry suspend without top-level status.
 */
export function workflowAwaitingHumanReview(result: unknown): boolean {
  if (!result || typeof result !== 'object') {
    return false;
  }
  const r = result as Record<string, unknown>;
  const status = r['status'];
  if (status === 'suspended' || status === 'waiting') {
    return true;
  }
  const steps = r['steps'] as
    | Record<string, { status?: string; suspendPayload?: unknown }>
    | undefined;
  const hr = steps?.['human-review'];
  if (hr?.suspendPayload !== undefined && hr?.suspendPayload !== null) {
    return true;
  }
  if (hr?.status === 'suspended' || hr?.status === 'waiting') {
    return true;
  }
  return draftFromSteps(r) !== null;
}

export function extractDraftNameFromMastraResult(result: unknown): string | null {
  if (!result || typeof result !== 'object') {
    return null;
  }
  const r = result as Record<string, unknown>;
  const fromSteps = draftFromSteps(r);
  if (typeof fromSteps?.name === 'string') {
    return fromSteps.name;
  }
  if (r['status'] === 'suspended' || r['status'] === 'waiting') {
    const sp = r['suspendPayload'] as Record<string, unknown> | undefined;
    const d = sp?.['draft'] as Record<string, unknown> | undefined;
    if (typeof d?.['name'] === 'string') {
      return d['name'];
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
