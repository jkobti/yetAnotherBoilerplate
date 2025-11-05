/*
  Firebase Cloud Messaging service worker (web push).
  Handles background notifications when the app is not in focus.
*/

importScripts('https://www.gstatic.com/firebasejs/9.6.11/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.6.11/firebase-messaging-compat.js');

const CONFIG_URL = '/env/local.json';

async function initFirebaseMessaging() {
  try {
    const response = await fetch(CONFIG_URL, { cache: 'no-cache' });
    if (!response.ok) {
      throw new Error(`Failed to load ${CONFIG_URL}: ${response.status}`);
    }

    const env = await response.json();
    const firebaseConfig = {
      apiKey: env.FIREBASE_API_KEY,
      appId: env.FIREBASE_APP_ID,
      messagingSenderId: env.FIREBASE_MESSAGING_SENDER_ID,
      projectId: env.FIREBASE_PROJECT_ID,
      authDomain: env.FIREBASE_AUTH_DOMAIN || undefined,
      storageBucket: env.FIREBASE_STORAGE_BUCKET || undefined,
    };

    firebase.initializeApp(firebaseConfig);

    const messaging = firebase.messaging();
    messaging.onBackgroundMessage((payload) => {
      console.log('[firebase-messaging-sw.js] Received background message ', payload);

      const title = (payload.notification && payload.notification.title) || 'New notification';
      const options = {
        body: (payload.notification && payload.notification.body) || '',
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        data: payload.data,
      };

      return self.registration.showNotification(title, options);
    });
  } catch (error) {
    console.error('[firebase-messaging-sw.js] Initialization error:', error);
  }
}

initFirebaseMessaging();

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  self.clients.claim();
});
