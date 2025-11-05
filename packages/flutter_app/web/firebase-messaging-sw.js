/*
  Firebase Cloud Messaging service worker (web push).
  Handles background notifications when the app is not in focus.
*/

importScripts('https://www.gstatic.com/firebasejs/9.6.11/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.6.11/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyD0J3ioAIFiYXeRrfWjKZRACYG38C9tUbs',
  appId: '1:477979509417:web:8b3ddb98a013671fad5fb8',
  messagingSenderId: '477979509417',
  projectId: 'yetanotherboilerplate',
  authDomain: 'yetanotherboilerplate.firebaseapp.com',
  storageBucket: 'yetanotherboilerplate.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  const title = (payload.notification && payload.notification.title) || 'New notification';
  const options = {
    body: (payload.notification && payload.notification.body) || '',
    icon: '/icons/Icon-192.png', // Optional: add your app icon
    badge: '/icons/Icon-192.png', // Optional: badge icon
    data: payload.data,
  };

  return self.registration.showNotification(title, options);
});

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  self.clients.claim();
});
