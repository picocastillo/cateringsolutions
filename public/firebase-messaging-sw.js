importScripts('https://www.gstatic.com/firebasejs/6.2.3/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/6.2.3/firebase-messaging.js');

var msid = new URL(location).searchParams.get('messagingSenderId');

firebase.initializeApp({
  'messagingSenderId': msid
});

const messaging = firebase.messaging();
