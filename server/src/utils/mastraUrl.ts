/**
 * Mastra HTTP routes live under `/api/...` on the Mastra server.
 * `MASTRA_API_URL` must be the service **origin only** (no `/api` suffix).
 * If someone sets `https://mastra.up.railway.app/api`, requests become `/api/api/workflows/...` → 404.
 */
export function normalizeMastraApiBase(url: string): string {
  let u = url.trim().replace(/\/+$/, '');
  u = u.replace(/\/api\/?$/i, '');
  return u;
}
