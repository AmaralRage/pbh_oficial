import fs from 'node:fs/promises';

// Read-only checks using the same public configuration bundled in the app.
// Never load user sessions, service keys or database credentials.
const source = await fs.readFile(new URL('../lib/core/config/supabase_config.dart', import.meta.url), 'utf8');
const url = source.match(/url\s*=\s*String\.fromEnvironment\([\s\S]*?defaultValue:\s*'([^']*)'/)?.[1];
const key = source.match(/publishableKey\s*=\s*String\.fromEnvironment\([\s\S]*?defaultValue:\s*'([^']*)'/)?.[1];
let publicKey = key?.startsWith('sb_publishable_');
try { publicKey ||= JSON.parse(Buffer.from(key.split('.')[1], 'base64url')).role === 'anon'; } catch {}
if (!url || !publicKey || !url.startsWith('https://')) throw new Error('Public app configuration is unavailable.');
const checks = [
  ['Perfis públicos', 'community_member_profile', {p_user_id: '00000000-0000-0000-0000-000000000000'}],
  ['Busca de membros', 'search_community_members', {p_query: '', p_offset: 0}],
  ['Editor de anexos', 'prepare_community_post_edit', {p_id: '00000000-0000-0000-0000-000000000000', p_paths: []}],
  ['Preferências de atividade', 'get_community_activity_preferences', {}],
  ['Diagnóstico administrativo', 'admin_community_health', {}],
];
const results = await Promise.all(checks.map(async ([feature, rpc, body]) => {
  try {
    const response = await fetch(`${url}/rest/v1/rpc/${rpc}`, {
      method: 'POST', signal: AbortSignal.timeout(15000),
      headers: {apikey: key, ...(!key.startsWith('sb_publishable_') ? {Authorization: `Bearer ${key}`} : {}), 'Content-Type': 'application/json'},
      body: JSON.stringify(body),
    });
    const result = await response.json();
    const status = response.ok ? 'available'
      : result?.code === '42501' ? 'available_requires_login'
      : result?.code === 'PGRST202' ? 'missing' : 'unverified';
    return {feature, status, http_status: response.status};
  } catch { return {feature, status: 'connection_unavailable'}; }
}));
console.log(JSON.stringify({checks: results, administrative_execution: 'requires_admin_session'}, null, 2));
