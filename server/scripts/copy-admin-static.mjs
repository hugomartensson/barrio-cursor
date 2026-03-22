/**
 * Copy admin HTML/JS into dist/admin so production serves the same files as src/admin
 * (tsc only emits .ts → .js; static assets must be copied).
 */
import { cpSync, mkdirSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const srcDir = path.join(root, 'src', 'admin');
const destDir = path.join(root, 'dist', 'admin');

function copyTree(src, dest) {
  mkdirSync(dest, { recursive: true });
  for (const name of readdirSync(src)) {
    const s = path.join(src, name);
    const d = path.join(dest, name);
    if (statSync(s).isDirectory()) {
      copyTree(s, d);
    } else if (name.endsWith('.html') || name.endsWith('.js')) {
      cpSync(s, d);
    }
  }
}

mkdirSync(destDir, { recursive: true });
copyTree(srcDir, destDir);
console.log('copy-admin-static: copied admin assets to dist/admin');
