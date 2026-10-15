window.pbhGetPushSubscription = async function (vapidKey) {
  if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) {
    throw new Error('Este navegador não oferece suporte a notificações push.');
  }

  const permission = await Notification.requestPermission();
  if (permission !== 'granted') throw new Error('Permissão de notificação não concedida.');

  const registration = await navigator.serviceWorker.register('./pbh-push-sw.js');
  let subscription = await registration.pushManager.getSubscription();
  if (!subscription) {
    const padding = '='.repeat((4 - (vapidKey.length % 4)) % 4);
    const base64 = (vapidKey + padding).replace(/-/g, '+').replace(/_/g, '/');
    const binary = atob(base64);
    const applicationServerKey = Uint8Array.from(binary, (character) => character.charCodeAt(0));
    subscription = await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey });
  }
  return JSON.stringify(subscription.toJSON());
};
