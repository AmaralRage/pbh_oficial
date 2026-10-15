import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return response({ error: 'Method not allowed' }, 405);

  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) return response({ error: 'Unauthorized' }, 401);

    const projectUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const token = authorization.slice('Bearer '.length);
    const userClient = createClient(projectUrl, anonKey, { global: { headers: { Authorization: authorization } } });
    const { data: userResult, error: userError } = await userClient.auth.getUser(token);
    if (userError || !userResult.user) return response({ error: 'Unauthorized' }, 401);

    const adminClient = createClient(projectUrl, serviceRoleKey);
    const { data: profile } = await adminClient.from('profiles').select('role').eq('id', userResult.user.id).maybeSingle();
    if (profile?.role !== 'admin') return response({ error: 'Forbidden' }, 403);

    const body = await request.json();
    const announcementId = String(body.announcementId ?? '').trim();
    if (!announcementId) return response({ error: 'Announcement ID is required' }, 400);

    const { data: announcement, error: announcementError } = await adminClient
      .from('announcements')
      .select('id, title, message, audience, destination_url')
      .eq('id', announcementId)
      .maybeSingle();
    if (announcementError) throw announcementError;
    if (!announcement) return response({ error: 'Announcement not found' }, 404);

    const publicKey = Deno.env.get('VAPID_PUBLIC_KEY');
    const privateKey = Deno.env.get('VAPID_PRIVATE_KEY');
    if (!publicKey || !privateKey) return response({ error: 'Web Push VAPID keys are not configured' }, 503);
    webpush.setVapidDetails(Deno.env.get('VAPID_SUBJECT') ?? 'mailto:amaralaragao31@gmail.com', publicKey, privateKey);

    const targetUsers = new Set<string>();
    for (let offset = 0; ; offset += 1000) {
      let usersQuery = adminClient.from('profiles').select('id');
      if (announcement.audience === 'members') usersQuery = usersQuery.eq('role', 'member');
      if (announcement.audience === 'admins') usersQuery = usersQuery.eq('role', 'admin');
      const { data, error } = await usersQuery.range(offset, offset + 999);
      if (error) throw error;
      for (const user of data ?? []) targetUsers.add(user.id);
      if (!data || data.length < 1000) break;
    }

    const subscriptions: Array<{ user_id: string; endpoint: string; p256dh: string; auth: string }> = [];
    for (let offset = 0; ; offset += 1000) {
      const { data, error } = await adminClient
        .from('web_push_subscriptions')
        .select('user_id, endpoint, p256dh, auth')
        .range(offset, offset + 999);
      if (error) throw error;
      subscriptions.push(...(data ?? []).filter((subscription) => targetUsers.has(subscription.user_id)));
      if (!data || data.length < 1000) break;
    }

    let sent = 0;
    let expired = 0;
    const payload = JSON.stringify({
      title: announcement.title,
      body: announcement.message,
      url: announcement.destination_url || '/',
      tag: `announcement-${announcement.id}`,
    });
    await Promise.all((subscriptions ?? []).map(async (subscription) => {
      try {
        await webpush.sendNotification({
          endpoint: subscription.endpoint,
          keys: { p256dh: subscription.p256dh, auth: subscription.auth },
        }, payload);
        sent++;
      } catch (error) {
        const statusCode = (error as { statusCode?: number }).statusCode;
        if (statusCode === 404 || statusCode === 410) {
          expired++;
          await adminClient.from('web_push_subscriptions').delete().eq('user_id', subscription.user_id).eq('endpoint', subscription.endpoint);
        }
      }
    }));

    const { error: metricsError } = await adminClient
      .from('announcements')
      .update({ push_attempted_count: subscriptions.length, push_accepted_count: sent })
      .eq('id', announcement.id);
    if (metricsError) throw metricsError;

    return response({ sent, attempted: subscriptions.length, expired });
  } catch (error) {
    console.error('send-announcement failed', error);
    return response({ error: 'Unable to send push notifications' }, 500);
  }
});

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
