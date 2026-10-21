/* Firebase Cloud Messaging service worker for web and installed iPhone PWAs. */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyC5mKprIKhdQFK1nLjHYFwW1eFUAlWA9Sw',
  appId: '1:943318599338:web:a9e591a04d009e302b72d3',
  messagingSenderId: '943318599338',
  projectId: 'nus-nus',
  authDomain: 'nus-nus.firebaseapp.com',
  storageBucket: 'nus-nus.firebasestorage.app',
  measurementId: 'G-3EMVG071P9',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'Nus·Nus';
  const options = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  return self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const targetUrl = new URL('/', self.location.origin);
  if (data.type === 'expense_created' || data.type === 'group_message') {
    for (const key of ['type', 'groupId', 'expenseId', 'messageId']) {
      if (typeof data[key] === 'string' && data[key].length > 0) {
        targetUrl.searchParams.set(`push_${key}`, data[key]);
      }
    }
  }
  const target = targetUrl.href;
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      const appClient = clients.find((client) => {
        try {
          return new URL(client.url).origin === self.location.origin;
        } catch (_) {
          return false;
        }
      });
      if (appClient && 'navigate' in appClient) {
        return appClient.navigate(target)
          .then((navigatedClient) => (navigatedClient || appClient).focus())
          .catch(() => self.clients.openWindow(target));
      }
      return self.clients.openWindow(target);
    }),
  );
});
