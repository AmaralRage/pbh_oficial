import type { SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'npm:jose@6';

type Announcement = { id: string; title: string; message: string; audience: string; sound_enabled?: boolean; destination_url?: string | null };
let cached: { token: string; expires: number } | undefined;

async function credentials() {
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('Native Push is not configured');
  const account = JSON.parse(raw);
  if (!account.client_email || !account.private_key || !/^[a-z0-9-]+$/.test(account.project_id)) throw new Error('Invalid FCM configuration');
  if (cached && cached.expires > Date.now()) return { project: account.project_id, token: cached.token };
  const key = await importPKCS8(account.private_key, 'RS256');
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256' }).setIssuer(account.client_email)
    .setAudience('https://oauth2.googleapis.com/token').setIssuedAt().setExpirationTime('1h').sign(key);
  const response = await fetch('https://oauth2.googleapis.com/token', { method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
    signal: AbortSignal.timeout(10000) });
  const data = await response.json();
  if (!response.ok || !data.access_token) throw new Error('FCM authorization failed');
  cached = { token: data.access_token, expires: Date.now() + Math.max(60, (data.expires_in ?? 3600) - 120) * 1000 };
  return { project: account.project_id, token: cached.token };
}

export async function sendNativeAnnouncement(admin: SupabaseClient, announcement: Announcement) {
  let auth: Awaited<ReturnType<typeof credentials>> | undefined;
  let failed = false;
  const expired: string[] = [];
  for (let offset = 0; ; offset += 100) {
    const { data: devices, error } = await admin.from('native_push_tokens')
      .select('installation_id,user_id,token').order('installation_id').range(offset, offset + 99);
    if (error) throw error;
    if (!devices?.length) break;
    let profiles = admin.from('profiles').select('id').in('id', devices.map((d) => d.user_id));
    if (announcement.audience === 'members') profiles = profiles.eq('role', 'member');
    if (announcement.audience === 'admins') profiles = profiles.eq('role', 'admin');
    const { data: eligible, error: audienceError } = await profiles;
    if (audienceError) throw audienceError;
    const ids = new Set((eligible ?? []).map((u) => u.id));
    const { data: receipts, error: receiptError } = await admin.from('announcement_push_receipts')
      .select('endpoint').eq('announcement_id', announcement.id).in('endpoint', devices.map((d) => `fcm:${d.token}`));
    if (receiptError) throw receiptError;
    const done = new Set((receipts ?? []).map((r) => r.endpoint));
    for (const device of devices.filter((d) => ids.has(d.user_id) && !done.has(`fcm:${d.token}`))) {
      auth ??= await credentials();
      // Recheck ownership before delivery; logging out removes this record.
      const { data: current, error: currentError } = await admin.from('native_push_tokens')
        .select('user_id,token').eq('installation_id', device.installation_id).maybeSingle();
      if (currentError) throw currentError;
      if (!current || current.user_id !== device.user_id || current.token !== device.token) continue;
      const silent = announcement.sound_enabled === false;
      let accepted = false;
      try {
        const response = await fetch(`https://fcm.googleapis.com/v1/projects/${auth.project}/messages:send`, {
          method: 'POST', headers: { Authorization: `Bearer ${auth.token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: { token: device.token,
            notification: { title: announcement.title, body: announcement.message },
            data: { announcement_id: announcement.id, recipient_id: device.user_id, silent: String(silent) },
            android: { priority: 'high', ttl: '86400s', notification: {
              channel_id: silent ? 'pbh_announcements_silent' : 'pbh_announcements',
              icon: 'ic_stat_pbh_prominent', tag: `announcement-${announcement.id}`,
              image: 'https://pbh-oficial.vercel.app/icons/Icon-512.png',
              color: '#6D28D9',
              ...(silent ? {} : { sound: 'default' }),
            } },
          } }), signal: AbortSignal.timeout(10000),
        });
        const result = await response.json();
        if (!response.ok) {
          const unregistered = result.error?.details?.some((d: { errorCode?: string }) => d.errorCode === 'UNREGISTERED');
          if (!unregistered) { failed = true; continue; }
          expired.push(device.token);
        } else { accepted = true; }
      } catch { failed = true; continue; }
      const { error: saveError } = await admin.from('announcement_push_receipts').upsert({
        announcement_id: announcement.id, endpoint: `fcm:${device.token}`, accepted,
      });
      if (saveError) throw saveError;
    }
    if (devices.length < 100) break;
  }
  for (const token of expired) await admin.from('native_push_tokens').delete().eq('token', token);
  if (failed) throw new Error('Native Push temporarily unavailable');
  const { count: attempted, error: countError } = await admin.from('announcement_push_receipts')
    .select('*', { count: 'exact', head: true }).eq('announcement_id', announcement.id).like('endpoint', 'fcm:%');
  const { count: sent, error: sentError } = await admin.from('announcement_push_receipts')
    .select('*', { count: 'exact', head: true }).eq('announcement_id', announcement.id).like('endpoint', 'fcm:%').eq('accepted', true);
  if (countError || sentError) throw countError || sentError;
  return { attempted: attempted ?? 0, sent: sent ?? 0 };
}
