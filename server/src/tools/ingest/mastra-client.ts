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
 * Starts the ingest workflow in the background using the two-step create-run + start pattern.
 * Returns immediately (fire-and-forget) — the workflow runs asynchronously on the Mastra server,
 * avoiding the Railway 180s HTTP gateway timeout that blocked the previous start-async approach.
 */
export async function runIngestWorkflow(
  input: IngestWorkflowInput
): Promise<{ runId: string }> {
  const base = mastraBase();

  // Step 1: create run → get runId immediately
  const createRes = await fetch(`${base}/api/workflows/ingest/create-run`, {
    method: 'POST',
    headers: headers(),
    body: JSON.stringify({}),
    signal: AbortSignal.timeout(15_000),
  });
  if (!createRes.ok) {
    const text = await createRes.text();
    logger.warn({ status: createRes.status, text }, 'Mastra create-run failed');
    throw new Error(`Mastra create-run failed: ${createRes.status}`);
  }
  const { runId } = (await createRes.json()) as { runId: string };

  // Step 2: start run in background (fire-and-forget — returns immediately)
  const startRes = await fetch(
    `${base}/api/workflows/ingest/start?runId=${encodeURIComponent(runId)}`,
    {
      method: 'POST',
      headers: headers(),
      body: JSON.stringify({ inputData: input }),
      signal: AbortSignal.timeout(15_000),
    }
  );
  if (!startRes.ok) {
    const text = await startRes.text();
    logger.warn({ status: startRes.status, text, runId }, 'Mastra start failed');
    throw new Error(`Mastra start failed: ${startRes.status}`);
  }

  logger.info({ runId }, 'Mastra ingest workflow started');
  return { runId };
}

/**
 * Polls a workflow run until it reaches a terminal state (suspended/success/failed/bailed).
 * Calls onDone with the final run record. Stops after maxMinutes.
 */
export function pollWorkflowRun(
  runId: string,
  onDone: (result: unknown) => Promise<void>,
  maxMinutes = 10
): void {
  const base = mastraBase();
  const url = `${base}/api/workflows/ingest/runs/${encodeURIComponent(runId)}`;
  const deadline = Date.now() + maxMinutes * 60_000;
  const interval = 20_000;

  const poll = async (): Promise<void> => {
    if (Date.now() > deadline) {
      logger.warn({ runId }, 'Workflow poll timed out');
      await onDone({ status: 'timeout' });
      return;
    }
    try {
      const res = await fetch(url, {
        headers: headers(),
        signal: AbortSignal.timeout(10_000),
      });
      if (!res.ok) {
        logger.warn({ runId, status: res.status }, 'Poll fetch failed, retrying');
        setTimeout(() => void poll(), interval);
        return;
      }
      const data = (await res.json()) as Record<string, unknown>;
      const status = data['status'] as string | undefined;
      if (
        status === 'suspended' ||
        status === 'waiting' ||
        status === 'success' ||
        status === 'failed' ||
        status === 'bailed'
      ) {
        logger.info({ runId, status }, 'Workflow reached terminal state');
        await onDone(data);
        return;
      }
      setTimeout(() => void poll(), interval);
    } catch (e) {
      logger.warn({ runId, err: String(e) }, 'Poll error, retrying');
      setTimeout(() => void poll(), interval);
    }
  };

  setTimeout(() => void poll(), interval);
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
