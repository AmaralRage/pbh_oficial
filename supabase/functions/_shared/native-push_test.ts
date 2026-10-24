import { createClient } from 'npm:@supabase/supabase-js@2';
import { sendNativeAnnouncement } from './native-push.ts';

const announcement = { id: 'announcement', title: 'Test', message: 'Body', audience: 'admins' };
const device = { installation_id: 'installation', user_id: 'member', token: 'private-device-token' };

function fixture(devices: typeof device[], eligible: boolean, delivered: boolean) {
  const requests: string[] = [];
  const client = createClient('https://fixture.supabase.co', 'test-key', {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch: (input, init) => {
      const url = new URL(String(input));
      if (url.hostname !== 'fixture.supabase.co') throw new Error('Unexpected external network request');
      requests.push(url.pathname);
      const result = url.pathname.endsWith('native_push_tokens') ? devices
        : url.pathname.endsWith('profiles') ? eligible ? [{ id: 'member' }] : []
        : delivered ? [{ endpoint: `fcm:${device.token}` }] : [];
      return Promise.resolve(new Response(init?.method === 'HEAD' ? null : JSON.stringify(result), {
        status: 200, headers: { 'Content-Type': 'application/json', 'Content-Range': delivered ? '0-0/1' : '*/0' },
      }));
    } },
  });
  return { client, requests };
}

Deno.test('no registered phones requires no FCM credentials and sends nothing', async () => {
  const { client } = fixture([], false, false);
  const result = await sendNativeAnnouncement(client, announcement);
  if (result.sent !== 0 || result.attempted !== 0) throw new Error('Unexpected delivery');
});

Deno.test('phones outside the selected audience receive nothing', async () => {
  const { client } = fixture([device], false, false);
  const result = await sendNativeAnnouncement(client, announcement);
  if (result.sent !== 0 || result.attempted !== 0) throw new Error('Audience filter failed');
});

Deno.test('confirmed delivery receipts prevent sending the same push again', async () => {
  const { client } = fixture([device], true, true);
  const result = await sendNativeAnnouncement(client, announcement);
  if (result.sent !== 1 || result.attempted !== 1) throw new Error('Delivery receipt not preserved');
});
