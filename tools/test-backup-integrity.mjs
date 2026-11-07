import fs from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createManifest, verifyManifest } from './backup-integrity.mjs';

test('backup verification detects tampering and missing files; never claims successful restore', async () => {
  const root = new URL(`../build/backup-tool-tests/${randomUUID()}/`, import.meta.url);
  await fs.mkdir(new URL('storage/fixture/', root), { recursive: true });
  for (const file of ['roles.sql', 'schema.sql', 'data.sql', 'storage/fixture/photo.bin']) await fs.writeFile(new URL(file, root), 'synthetic fixture');
  const directory = (await import('node:url')).fileURLToPath(root);
  assert.deepEqual(await createManifest(directory), { files: 4, storage_files: 1 });
  assert.equal((await verifyManifest(directory)).restoration_tested, false);
  await assert.rejects(createManifest(directory), /EEXIST/);
  await fs.writeFile(new URL('storage/fixture/photo.bin', root), 'corrupted');
  await assert.rejects(verifyManifest(directory), /does not match/);
  await fs.unlink(new URL('data.sql', root));
  await assert.rejects(verifyManifest(directory), /added, removed or renamed/);
});
