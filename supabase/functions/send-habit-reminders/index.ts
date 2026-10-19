import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'npm:@supabase/supabase-js@2';

const habits: Record<string, { emoji: string; title: string; deadline: number; message: string }> = {
  train: { emoji: '🏋️', title: 'Treinar o corpo', deadline: 20 * 60, message: 'Seu treino ainda cabe no dia. Faça os 45 minutos que prometeu a si mesmo.' },
  read: { emoji: '📚', title: 'Ler ou estudar', deadline: 21 * 60, message: 'Reserve 30 minutos para ler ou estudar. Um pouco todos os dias transforma o futuro.' },
  digital_fast: { emoji: '🧭', title: 'Sem pornografia', deadline: 21 * 60 + 30, message: 'Proteja o foco que voce construiu. Sua meta de hoje ainda esta em andamento.' },
  meditate: { emoji: '🧘', title: 'Meditar / Orar', deadline: 21 * 60, message: 'Dez minutos de silencio, meditacao ou oracao tambem fazem parte da disciplina.' },
  sleep_early: { emoji: '🌙', title: 'Dormir cedo', deadline: 22 * 60, message: 'Desacelere para proteger sua meta de dormir cedo e recomecar bem amanha.' },
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const expectedSecret = Deno.env.get('HABIT_REMINDER_CRON_SECRET');
  if (!expectedSecret || request.headers.get('x-pbh-cron-secret') !== expectedSecret) {
    return json({ error: 'Unauthorized' }, 401);
  }

  try {
    const projectUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const publicKey = Deno.env.get('VAPID_PUBLIC_KEY');
    const privateKey = Deno.env.get('VAPID_PRIVATE_KEY');
    if (!publicKey || !privateKey) return json({ error: 'Web Push VAPID keys are not configured' }, 503);
    webpush.setVapidDetails(Deno.env.get('VAPID_SUBJECT') ?? 'mailto:amaralaragao31@gmail.com', publicKey, privateKey);

    const admin = createClient(projectUrl, serviceRoleKey);
    const now = new Date();
    let checked = 0;
    let sent = 0;
    let skipped = 0;
    let failed = 0;

    for (let offset = 0; ; offset += 500) {
      const { data: settings, error } = await admin.from('habit_reminder_settings')
        .select('user_id, reminder_time, time_zone, selected_habit_keys')
        .eq('delivery_mode', 'web').eq('enabled', true).range(offset, offset + 499);
      if (error) throw error;

      for (const setting of settings ?? []) {
        checked++;
        let local: Record<string, string>;
        try {
          local = localClock(now, setting.time_zone);
        } catch {
          skipped++;
          continue;
        }
        const currentMinutes = Number(local.hour) * 60 + Number(local.minute);
        const selected = (setting.selected_habit_keys as string[]).filter((key) => key in habits);
        if (selected.length === 0) continue;
        const { data: completed, error: completionError } = await admin.from('habit_completions')
          .select('habit_key').eq('user_id', setting.user_id).eq('completed_on', local.date).in('habit_key', selected);
        if (completionError) throw completionError;
        const completedKeys = new Set((completed ?? []).map((row) => row.habit_key as string));
        const pending = selected.filter((key) => !completedKeys.has(key));
        if (pending.length === 0) continue;

        const [targetHour, targetMinute] = String(setting.reminder_time).slice(0, 5).split(':').map(Number);
        const customReminderDue = currentMinutes >= targetHour * 60 + targetMinute;
        const due = customReminderDue
          ? pending
          : pending.filter((key) => currentMinutes >= habits[key].deadline);
        // Send at each habit cutoff or at the member's chosen reminder time.
        if (due.length === 0) continue;

        const { data: claimed, error: claimError } = await admin.rpc('claim_habit_reminder', {
          p_user_id: setting.user_id,
          p_reminder_on: local.date,
        });
        if (claimError) throw claimError;
        if (!claimed) continue;

        const { data: subscriptions, error: subscriptionsError } = await admin.from('web_push_subscriptions')
          .select('user_id, endpoint, p256dh, auth').eq('user_id', setting.user_id);
        if (subscriptionsError) {
          await admin.rpc('release_habit_reminder', { p_user_id: setting.user_id, p_reminder_on: local.date });
          throw subscriptionsError;
        }
        if (!subscriptions?.length) {
          await admin.rpc('release_habit_reminder', { p_user_id: setting.user_id, p_reminder_on: local.date });
          skipped++;
          continue;
        }

        const focus = habits[due[0]];
        const taskList = due.map((key) => `${habits[key].emoji} ${habits[key].title}`).join(' · ');
        const payload = JSON.stringify({
          title: `${focus.emoji} ${focus.title} ainda te espera`,
          body: `${focus.message}${due.length > 1 ? ` Outras tarefas pendentes: ${taskList}.` : ''}`,
          icon: './icons/Icon-192.png',
          badge: './icons/Icon-192.png',
          url: './',
          tag: `pbh-habit-reminder-${local.date}`,
          vibrate: [180, 80, 180],
        });
        let accepted = 0;
        await Promise.all(subscriptions.map(async (subscription) => {
          try {
            await webpush.sendNotification({
              endpoint: subscription.endpoint,
              keys: { p256dh: subscription.p256dh, auth: subscription.auth },
            }, payload);
            accepted++;
          } catch (pushError) {
            const statusCode = (pushError as { statusCode?: number }).statusCode;
            if (statusCode === 404 || statusCode === 410) {
              await admin.from('web_push_subscriptions').delete()
                .eq('user_id', subscription.user_id).eq('endpoint', subscription.endpoint);
            }
          }
        }));
        if (accepted > 0) sent++;
        else {
          await admin.rpc('release_habit_reminder', { p_user_id: setting.user_id, p_reminder_on: local.date });
          failed++;
        }
      }

      if (!settings || settings.length < 500) break;
    }

    return json({ checked, sent, skipped, failed });
  } catch (error) {
    console.error('send-habit-reminders failed', error);
    return json({ error: 'Unable to send habit reminders' }, 500);
  }
});

function localClock(date: Date, timeZone: string): Record<string, string> {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map(({ type, value }) => [type, value]));
  return { ...values, date: `${values.year}-${values.month}-${values.day}` };
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}
