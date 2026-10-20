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
  const target = new URL('/', self.location.origin).href;
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if ('focus' in client) return client.focus();
      }
      return self.clients.openWindow(target);
    }),
  );
});
