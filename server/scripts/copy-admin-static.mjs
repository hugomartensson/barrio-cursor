/**
 * Copy admin HTML/JS into dist/admin so production serves the same files as src/admin
 * (tsc only emits .ts → .js; static assets must be copied).
 */
import { cpSync, mkdirSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const srcDir = path.join(root, 'src', 'admin');
const destDir = path.join(root, 'dist', 'admin');

mkdirSync(destDir, { recursive: true });
for (const name of readdirSync(srcDir)) {
  if (name.endsWith('.html') || name.endsWith('.js')) {
    cpSync(path.join(srcDir, name), path.join(destDir, name));
  }
}
console.log('copy-admin-static: copied admin assets to dist/admin');
