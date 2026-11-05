import fs from 'node:fs/promises';
const source = await fs.readFile(new URL('../lib/core/config/supabase_config.dart', import.meta.url), 'utf8');
const url = source.match(/url\s*=\s*String\.fromEnvironment\([\s\S]*?defaultValue:\s*'([^']*)'/)?.[1];
const key = source.match(/publishableKey\s*=\s*String\.fromEnvironment\([\s\S]*?defaultValue:\s*'([^']*)'/)?.[1];
let safe = key?.startsWith('sb_publishable_');
try { safe ||= JSON.parse(Buffer.from(key.split('.')[1], 'base64url')).role === 'anon'; } catch {}
if (!safe || !url?.startsWith('https://')) throw new Error('Expected public configuration.');
// Zero-row probes never download personal records. No sessions or secret keys.
const probes = [
  ['profile_email', 'profiles?select=email&limit=0', {}],
  ['auth_password_hash', 'users?select=encrypted_password&limit=0', {'Accept-Profile': 'auth'}],
  ['private_goals', 'personal_goals?select=user_id&limit=0', {}],
  ['private_push', 'web_push_subscriptions?select=user_id&limit=0', {}],
  ['private_native_push', 'native_push_tokens?select=user_id&limit=0', {}],
  ['private_habits', 'habit_completions?select=user_id&limit=0', {}],
];
for (const [check, path, extra] of probes) {
  try {
    const r = await fetch(`${url}/rest/v1/${path}`, {headers: {apikey: key, Authorization: `Bearer ${key}`, Prefer: 'count=exact', ...extra}, signal: AbortSignal.timeout(15000)});
    const body = await r.json();
    console.log(JSON.stringify({check, status: r.status, code: Array.isArray(body) ? null : body.code, range: r.headers.get('content-range')}));
  } catch { console.log(JSON.stringify({check, status: 'connection_unavailable'})); }
}
