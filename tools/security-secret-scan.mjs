import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

process.chdir(fileURLToPath(new URL('../', import.meta.url)));
const git = (...args) => execFileSync('git', args, { maxBuffer: 32 * 1024 * 1024 });
const rules = [
  ['supabase_secret', /sb_secret_[A-Za-z0-9_-]{16,}/g],
  ['private_key', /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g],
  ['aws_access_key', /\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/g],
];
export function secretKinds(buffer) {
  if (buffer.includes(0)) return []; // Binary files need separate analysis.
  const source = buffer.toString('utf8'), found = [];
  for (const [kind, pattern] of rules) {
    pattern.lastIndex = 0;
    if (pattern.test(source)) found.push(kind);
  }
  for (const match of source.matchAll(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g)) {
    try {
      if (JSON.parse(Buffer.from(match[0].split('.')[1], 'base64url')).role === 'service_role') found.push('service_role_jwt');
    } catch { /* Not a JWT payload. */ }
  }
  return [...new Set(found)];
}
export function forbiddenPath(path) {
  if (/^(backups|security-private)\//i.test(path) || /\.dump$/i.test(path)) return true;
  if (/(^|\/)\.env(?:\.|$)/i.test(path) && !/\.example$/i.test(path)) return true;
  return /(?:\.jks|\.keystore|\.p12|\.pfx|\.key)$/i.test(path) || /(^|\/)key\.properties$/i.test(path)
    || /service[-_]account[^/]*\.json$/i.test(path);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) run();
function run() {
  const findings = [], files = new Set(git('ls-files', '--cached', '--others', '--exclude-standard', '-z').toString().split('\0').filter(Boolean));
  let inspected = 0, blobs = 0;
  const scan = (buffer, location) => {
    for (const kind of secretKinds(buffer)) findings.push({ location, kind });
  };
  for (const path of files) {
    if (forbiddenPath(path)) findings.push({ location: path, kind: 'credential_file' });
    if (!fs.existsSync(path) || !fs.statSync(path).isFile()) continue;
    const buffer = fs.readFileSync(path);
    scan(buffer, path); inspected++;
    if (/^(lib|web|assets)\//.test(path) && !buffer.includes(0)
        && /SUPABASE_SERVICE_ROLE_KEY|SUPABASE_SECRET_KEY|FCM_SERVICE_ACCOUNT_JSON|VAPID_PRIVATE_KEY/.test(buffer.toString())) {
      findings.push({ location: path, kind: 'server_credential_reference_in_frontend' });
    }
  }
  // Check the actual compiled frontend when present, including CI's release build.
  for (const path of ['build/web/main.dart.js', 'build/web/flutter_bootstrap.js']) if (fs.existsSync(path)) scan(fs.readFileSync(path), path);
  if (process.argv.includes('--history')) {
    const ids = git('rev-list', '--objects', '--all').toString().split('\n').map(line => line.split(' ')[0]).filter(Boolean);
    const metadata = execFileSync('git', ['cat-file', '--batch-check'], { input: ids.join('\n') + '\n', maxBuffer: 32 * 1024 * 1024 });
    const objects = metadata.toString().trim().split('\n').filter(line => line.split(' ')[1] === 'blob').map(line => line.split(' ')[0]);
    // Read small batches instead of loading the whole history into RAM.
    for (let start = 0; start < objects.length; start += 20) {
      const data = execFileSync('git', ['cat-file', '--batch'], { input: objects.slice(start, start + 20).join('\n') + '\n', maxBuffer: 128 * 1024 * 1024 });
      for (let position = 0; position < data.length;) {
        const end = data.indexOf(10, position);
        const [id, , length] = data.subarray(position, end).toString().split(' ');
        const size = Number(length);
        scan(data.subarray(end + 1, end + 1 + size), `git:${id}`); blobs++;
        position = end + 1 + size + 1;
      }
    }
  }
  console.log(JSON.stringify({ files: inspected, history_blobs: blobs, findings }, null, 2));
  if (findings.length) process.exitCode = 1;
}
