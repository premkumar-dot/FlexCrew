// Replace firebaseConfig values with your project's web config (from FlutterFire/Firebase console)
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-messaging-compat.js');

const firebaseConfig = {
    apiKey: "<API_KEY>",
    authDomain: "<PROJECT>.firebaseapp.com",
    projectId: "<PROJECT_ID>",
    storageBucket: "<BUCKET>",
    messagingSenderId: "<SENDER_ID>",
    appId: "<APP_ID>",
    measurementId: "<MEASUREMENT_ID>"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
    const title = payload.notification?.title || 'Notification';
    const options = { body: payload.notification?.body || '' };
    self.registration.showNotification(title, options);
});