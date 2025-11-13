/*
  Firebase Cloud Messaging service worker (web push).
  Handles background notifications when the app is not in focus.

  This file is a template. The build script will inject Firebase config at build time.
*/

importScripts('https://www.gstatic.com/firebasejs/9.6.11/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.6.11/firebase-messaging-compat.js');

// Firebase config will be injected here at build time
const FIREBASE_CONFIG = {"apiKey":"YOUR_KEY","appId":"YOUR_APP_ID","messagingSenderId":"YOUR_SENDER_ID","projectId":"YOUR_PROJECT_ID","authDomain":"YOUR_AUTH_DOMAIN (optional)","storageBucket":"YOUR_STORAGE_BUCKET (optional)"};

async function initFirebaseMessaging() {
  try {
    if (!FIREBASE_CONFIG || !FIREBASE_CONFIG.apiKey) {
      console.error('[firebase-messaging-sw.js] Firebase config not provided');
      return;
    }

    firebase.initializeApp(FIREBASE_CONFIG);

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
