import { test } from 'node:test';
import assert from 'node:assert/strict';
import { secretKinds, forbiddenPath } from './security-secret-scan.mjs';

test('secret scanner distinguishes public keys from privileged credentials without printing values', () => {
  const jwt = role => ['eyJhbGciOiJIUzI1NiJ9', Buffer.from(JSON.stringify({ role })).toString('base64url'), 'fixture_signature'].join('.');
  const scan = source => secretKinds(Buffer.from(source));
  assert.deepEqual(scan('sb_publishable_' + 'a'.repeat(30)), []);
  assert.deepEqual(scan(jwt('anon')), []);
  assert.deepEqual(scan(jwt('service_role')), ['service_role_jwt']);
  assert.deepEqual(scan('sb_' + 'secret_' + 'a'.repeat(30)), ['supabase_secret']);
  assert.deepEqual(scan('-----BEGIN ' + 'PRIVATE KEY-----'), ['private_key']);
  assert.deepEqual(scan('AK' + 'IA' + 'A'.repeat(16)), ['aws_access_key']);
  for (const path of ['.env', '.env.local', 'android/key.properties', 'keys/release.jks', 'credentials/service-account.json', 'backups/data.sql', 'security-private/report.json', 'snapshot.dump']) assert.equal(forbiddenPath(path), true, path);
  for (const path of ['.env.example', '.env.production.example', 'lib/core/config/supabase_config.dart']) assert.equal(forbiddenPath(path), false, path);
});
