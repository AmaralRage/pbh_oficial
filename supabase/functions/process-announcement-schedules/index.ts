import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'npm:@supabase/supabase-js@2';
import { sendNativeAnnouncement } from '../_shared/native-push.ts';

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const secret = Deno.env.get('ANNOUNCEMENT_CRON_SECRET');
  if (!secret || request.headers.get('x-pbh-cron-secret') !== secret) return json({ error: 'Unauthorized' }, 401);
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  let processed = 0;
  try {
    // Database cron publishes messages even if Web Push is unavailable.
    for (let i = 0; i < 5; i++) {
      const { data, error } = await admin.rpc('claim_scheduled_announcement_push');
      if (error) throw error;
      const schedule = data?.[0];
      if (!schedule) break;
      let deliveryError: string | null = null;
      try {
        const publicKey = Deno.env.get('VAPID_PUBLIC_KEY');
        const privateKey = Deno.env.get('VAPID_PRIVATE_KEY');
        if (!publicKey || !privateKey) throw new Error('Web Push is not configured');
        webpush.setVapidDetails(Deno.env.get('VAPID_SUBJECT') ?? 'mailto:amaralaragao31@gmail.com', publicKey, privateKey);
        let transientFailure = false;
        for (let offset = 0; ; offset += 100) {
          const { data: subscriptions, error: subscriptionsError } = await admin.from('web_push_subscriptions')
            .select('user_id,endpoint,p256dh,auth').order('endpoint').range(offset, offset + 99);
          if (subscriptionsError) throw subscriptionsError;
          const userIds = [...new Set((subscriptions ?? []).map((s) => s.user_id))];
          let users = admin.from('profiles').select('id').in('id', userIds);
          if (schedule.audience === 'members') users = users.eq('role', 'member');
          if (schedule.audience === 'admins') users = users.eq('role', 'admin');
          const { data: eligible, error: audienceError } = userIds.length ? await users : { data: [], error: null };
          if (audienceError) throw audienceError;
          const recipients = new Set((eligible ?? []).map((u) => u.id));
          if (!subscriptions?.length) break;
          const { data: receipts, error: receiptError } = await admin.from('announcement_push_receipts')
            .select('endpoint').eq('announcement_id', schedule.announcement_id)
            .in('endpoint', subscriptions.map((s) => s.endpoint));
          if (receiptError) throw receiptError;
          const delivered = new Set((receipts ?? []).map((r) => r.endpoint));
          const targets = (subscriptions ?? []).filter((s) => recipients.has(s.user_id) && !delivered.has(s.endpoint));
          for (let batch = 0; batch < targets.length; batch += 10) {
            await Promise.all(targets.slice(batch, batch + 10).map(async (subscription) => {
              let accepted = true;
              try {
                await webpush.sendNotification({ endpoint: subscription.endpoint,
                  keys: { p256dh: subscription.p256dh, auth: subscription.auth } }, JSON.stringify({
                  title: schedule.title, body: schedule.message,
                  url: schedule.destination_url || '/', tag: `announcement-${schedule.announcement_id}`,
                  silent: !schedule.sound_enabled,
                }), { timeout: 10000, TTL: 86400 });
              } catch (error) {
                const status = (error as { statusCode?: number }).statusCode;
                if (status !== 404 && status !== 410) { transientFailure = true; return; }
                // Store expired endpoints as terminal receipts. Do not delete while paginating.
                accepted = false;
              }
              const { error } = await admin.from('announcement_push_receipts').upsert({
                announcement_id: schedule.announcement_id, endpoint: subscription.endpoint, accepted,
              });
              if (error) throw error;
            }));
          }
          if (!subscriptions || subscriptions.length < 100) break;
        }
        await sendNativeAnnouncement(admin, { ...schedule, id: schedule.announcement_id });
        const { count: total, error: totalsError } = await admin.from('announcement_push_receipts')
          .select('*', { count: 'exact', head: true }).eq('announcement_id', schedule.announcement_id);
        if (totalsError) throw totalsError;
        const { count: accepted, error: acceptedError } = await admin.from('announcement_push_receipts')
          .select('*', { count: 'exact', head: true }).eq('announcement_id', schedule.announcement_id).eq('accepted', true);
        if (acceptedError) throw acceptedError;
        const { error: metricsError } = await admin.from('announcements').update({
          push_attempted_count: total ?? 0,
          push_accepted_count: accepted ?? 0,
        }).eq('id', schedule.announcement_id);
        if (metricsError) throw metricsError;
        if (transientFailure) throw new Error('Some push services are temporarily unavailable');
      } catch (error) {
        // Store only controlled diagnostics, never endpoints or push credentials.
        console.error('Scheduled announcement delivery failed', schedule.id);
        deliveryError = error instanceof Error && error.message === 'Web Push is not configured'
          ? error.message : 'Web Push delivery temporarily unavailable';
      }
      const { error: finishError } = await admin.rpc('finish_scheduled_announcement_push', {
        p_id: schedule.id, p_lease: schedule.lease_id, p_error: deliveryError,
      });
      if (finishError) throw finishError;
      processed++;
    }
    return json({ processed });
  } catch {
    return json({ error: 'Unable to process scheduled announcements' }, 500);
  }
});

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}
