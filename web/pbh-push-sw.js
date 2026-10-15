self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (_) {
    payload = { body: event.data ? event.data.text() : '' };
  }

  event.waitUntil(self.registration.showNotification(payload.title || 'PBH Oficial', {
    body: payload.body || 'Há uma nova mensagem na comunidade.',
    icon: './icons/Icon-192.png',
    badge: './icons/Icon-192.png',
    tag: payload.tag || 'pbh-announcement',
    data: { url: payload.url || './' },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL(event.notification.data?.url || './', self.location.origin).href;
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
    for (const client of windows) {
      if (client.url.startsWith(self.location.origin) && 'focus' in client) return client.focus();
    }
    return clients.openWindow ? clients.openWindow(target) : undefined;
  }));
});
