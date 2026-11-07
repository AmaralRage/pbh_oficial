import fs from 'node:fs/promises';
import { createReadStream } from 'node:fs';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const manifestName = 'backup-manifest.json';
const required = ['roles.sql', 'schema.sql', 'data.sql'];
async function inventory(root, directory = '') {
  const files = [];
  for (const entry of await fs.readdir(path.join(root, directory), { withFileTypes: true })) {
    const relative = directory ? `${directory}/${entry.name}` : entry.name;
    if (relative === manifestName) continue;
    if (entry.isSymbolicLink()) throw Error('Backup contains a symbolic link; copy real files instead.');
    if (entry.isDirectory()) files.push(...await inventory(root, relative));
    else if (entry.isFile()) files.push(relative);
    else throw Error('Backup contains an unsupported file type.');
  }
  return files.sort();
}
async function fingerprint(root, relative) {
  if (!relative || relative.includes('\\') || relative.split('/').some(part => !part || part === '.' || part === '..') || path.isAbsolute(relative)) throw Error('Invalid backup manifest path.');
  const hash = createHash('sha256');
  let bytes = 0;
  for await (const chunk of createReadStream(path.join(root, relative))) { hash.update(chunk); bytes += chunk.length; }
  return { path: relative, bytes, sha256: hash.digest('hex') };
}
export async function createManifest(directory) {
  const root = path.resolve(directory), names = await inventory(root);
  for (const name of required) {
    if (!names.includes(name) || (await fs.stat(path.join(root, name))).size === 0) throw Error('Expected nonempty roles.sql, schema.sql and data.sql exports.');
  }
  const files = [];
  for (const name of names) files.push(await fingerprint(root, name));
  const manifest = { version: 1, created_at: new Date().toISOString(), files };
  await fs.writeFile(path.join(root, manifestName), JSON.stringify(manifest, null, 2) + '\n', { flag: 'wx' });
  return { files: files.length, storage_files: names.filter(name => name.startsWith('storage/')).length };
}
export async function verifyManifest(directory) {
  const root = path.resolve(directory);
  const manifest = JSON.parse(await fs.readFile(path.join(root, manifestName), 'utf8'));
  if (manifest.version !== 1 || !Array.isArray(manifest.files)) throw Error('Unsupported manifest.');
  const actual = await inventory(root), expected = manifest.files.map(file => file.path).sort();
  if (actual.length !== expected.length || actual.some((name, index) => name !== expected[index])) throw Error('Backup files were added, removed or renamed.');
  for (const file of manifest.files) {
    const current = await fingerprint(root, file.path);
    if (file.bytes !== current.bytes || file.sha256 !== current.sha256) throw Error('Backup content does not match its manifest.');
  }
  return { files: actual.length, content_integrity_verified: true, restoration_tested: false };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [, , mode, directory] = process.argv;
  try {
    if (!directory || !['create', 'verify'].includes(mode)) throw Error('Usage: node tools/backup-integrity.mjs <create|verify> <backup-directory>');
    console.log(JSON.stringify(await (mode === 'create' ? createManifest(directory) : verifyManifest(directory))));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
