/* istanbul ignore file */
import fs from 'node:fs/promises';
import YAML from 'yaml';
import { config } from '../../config/index.js';
import { normalizeMastraApiBase } from '../../utils/mastraUrl.js';

type BatchItem = {
  url?: string;
  manual?: Record<string, unknown>;
  override?: Record<string, unknown>;
  type?: string;
};

type BatchFile = {
  collection?: { name: string; description?: string; visibility?: string };
  items: BatchItem[];
};

type IngestWorkflowInput = {
  inputType: 'telegram_link' | 'telegram_text' | 'batch_yaml';
  rawInput: string;
  contextNote: string | null;
};

const mastraBase = (): string =>
  normalizeMastraApiBase(config.MASTRA_API_URL ?? 'http://127.0.0.1:4111');

const mastraHeaders = (): Record<string, string> => {
  const h: Record<string, string> = {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  };
  if (config.MASTRA_SERVER_TOKEN) {
    h['Authorization'] = `Bearer ${config.MASTRA_SERVER_TOKEN}`;
  }
  return h;
};

async function portalLogin(): Promise<string> {
  const email = config.PORTAL_EMAIL ?? config.PORTAL_TEAM_EMAIL;
  const password = config.PORTAL_PASSWORD ?? config.PORTAL_TEAM_PASSWORD;
  if (!email || !password) {
    throw new Error(
      'Set PORTAL_EMAIL/PORTAL_PASSWORD (or PORTAL_TEAM_*) for batch collection creation'
    );
  }
  const api = (config.PORTAL_API_URL ?? 'http://localhost:3000/api').replace(/\/$/, '');
  const res = await fetch(`${api}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const json = (await res.json()) as { data?: { token?: string } };
  const token = json.data?.token;
  if (!token) {
    throw new Error('Portal login failed for batch runner');
  }
  return token;
}

async function createCollection(
  token: string,
  name: string,
  description?: string
): Promise<string> {
  const api = (config.PORTAL_API_URL ?? 'http://localhost:3000/api').replace(/\/$/, '');
  const res = await fetch(`${api}/collections`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ name, description, visibility: 'public' }),
  });
  const json = (await res.json()) as { data?: { id?: string } };
  const id = json.data?.id;
  if (!id) {
    throw new Error('Collection create failed');
  }
  return id;
}

async function startIngest(input: IngestWorkflowInput): Promise<unknown> {
  const url = `${mastraBase()}/api/workflows/ingest/start-async`;
  const res = await fetch(url, {
    method: 'POST',
    headers: mastraHeaders(),
    body: JSON.stringify({ inputData: input }),
    signal: AbortSignal.timeout(300_000),
  });
  const text = await res.text();
  let json: unknown;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    throw new Error(`Mastra workflow HTTP ${res.status}: ${text.slice(0, 200)}`);
  }
  return json;
}

const main = async (): Promise<void> => {
  const yamlPath = process.argv[2];
  if (!yamlPath) {
    throw new Error('Usage: npm run batch -- ./path/to/file.yaml');
  }

  const fileContent = await fs.readFile(yamlPath, 'utf8');
  const parsed = YAML.parse(fileContent) as BatchFile;
  if (!parsed.items?.length) {
    throw new Error('YAML file has no items');
  }

  let collectionNote = '';
  if (parsed.collection) {
    const token = await portalLogin();
    const id = await createCollection(
      token,
      parsed.collection.name,
      parsed.collection.description
    );
    collectionNote = `\n\nUse collectionId "${id}" when approving in the ingest dashboard (or add resume support later).`;
    // eslint-disable-next-line no-console
    console.log(`Created collection ${id} (${parsed.collection.name})`);
  }

  let started = 0;
  for (const item of parsed.items) {
    let rawInput: string;
    if (item.url) {
      rawInput = item.url;
    } else if (item.manual) {
      rawInput = JSON.stringify({ ...item.manual, ...(item.override ?? {}) });
    } else {
      // eslint-disable-next-line no-console
      console.log('Skipping item with no url or manual');
      continue;
    }

    const input: IngestWorkflowInput = {
      inputType: item.url ? 'batch_yaml' : 'batch_yaml',
      rawInput,
      contextNote: item.override
        ? `YAML overrides: ${JSON.stringify(item.override)}${collectionNote}`
        : collectionNote || null,
    };

    try {
      const result = await startIngest(input);
      started += 1;
      const status = (result as { status?: string })?.status;
      // eslint-disable-next-line no-console
      console.log(`Started workflow (${status ?? 'unknown'}): ${rawInput.slice(0, 80)}…`);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('Failed item:', e);
    }
  }

  // eslint-disable-next-line no-console
  console.log(
    `Queued ${started}/${parsed.items.length} ingest workflow run(s). Review at /admin/ingest/`
  );
};

void main();
