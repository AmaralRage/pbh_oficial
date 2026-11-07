self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (_) {
    payload = { body: event.data ? event.data.text() : '' };
  }

  event.waitUntil(self.registration.showNotification(payload.title || 'PBH Oficial', {
    body: payload.body || 'Há uma nova mensagem na comunidade.',
    icon: payload.icon || './icons/Icon-192.png',
    badge: payload.badge || './icons/Icon-192.png',
    tag: payload.tag || 'pbh-announcement',
    silent: payload.silent === true,
    ...(payload.silent === true ? {} : { vibrate: payload.vibrate || [120, 60, 120] }),
    data: { url: payload.url || './' },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  let target;
  try {
    target = new URL(event.notification.data?.url || './', self.location.origin);
    if (target.protocol !== 'https:' && target.origin !== self.location.origin) throw new Error('Unsupported destination');
  } catch (_) { target = new URL('/', self.location.origin); }
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(async (windows) => {
    for (const client of windows) {
      if (target.origin !== self.location.origin || new URL(client.url).origin !== self.location.origin) continue;
      if (!('navigate' in client) || !('focus' in client)) continue;
      try {
        const navigated = await client.navigate(target.href);
        if (navigated) return navigated.focus();
      } catch (_) { /* A closing tab must not consume the destination. */ }
    }
    return clients.openWindow ? clients.openWindow(target.href) : undefined;
  }));
});
