// Changing the cache version will cause existing cached resources to be
// deleted the next time the service worker is re-installed and re-activated.
const CACHE_VERSION = 1;
const CURRENT_CACHE = `catering-v-${CACHE_VERSION}`;
const OFFLINE_PAGE_URL = 'offline';
const ASSETS_TO_BE_CACHED = [OFFLINE_PAGE_URL];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CURRENT_CACHE).then((cache) => {
      // addAll() hits all the URIs in the array and caches
      // the results, with the URIs as the keys.
      cache.addAll(ASSETS_TO_BE_CACHED)
           .catch(err => console.log('Error while fetching assets', err));
     })
  );
});

self.addEventListener('activate', event => {
  // Delete all caches except for CURRENT_CACHE, thus deleting the previous cache
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CURRENT_CACHE) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});

self.addEventListener("fetch", (event) => {
  // We only want to call event.respondWith() if this is a navigation request
  // for an HTML page.
  //if (event.request.mode === "navigate") {
  //  event.respondWith(
  //    (async () => {
  //      try {
  //        // Always try the network first.
  //        const networkResponse = await fetch(event.request);
  //        return networkResponse;
  //      } catch (error) {
          // catch is only triggered if an exception is thrown, which is likely
          // due to a network error.
          // If fetch() returns a valid HTTP response with a response code in
          // the 4xx or 5xx range, the catch() will NOT be called.
  //        console.log("Fetch failed; returning offline page instead.", error);
  //        const cache = await caches.open(CURRENT_CACHE);
  //        const cachedResponse = await cache.match(OFFLINE_PAGE_URL);
  //        return cachedResponse;
  //      }
  //    })()
  //  );
  //}

  // If our if() condition is false, then this fetch handler won't intercept the
  // request. If there are any other fetch handlers registered, they will get a
  // chance to call event.respondWith(). If no fetch handlers call
  // event.respondWith(), the request will be handled by the browser as if there
  // were no service worker involvement.
});

self.addEventListener('fetchtr', (e) => {
  const request = e.request;
  let response = fetch(request)
    .then((response) => response)
    .catch((error) => caches.match(OFFLINE_PAGE_URL));

  e.respondWith(response);
});

self.addEventListener('push', function(event) {
  const { body, title, tag, url, image } = JSON.parse(event.data.text());
  const options = {
    body: body,
    icon: '/launcher-icon-1x.png',
    badge: '/badge.png',
    tag: tag,
    data: { url: url },
    image: image
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  url = event.notification.data.url;
  event.waitUntil(clients.matchAll({type: 'window'}).then( windowClients => {
              // Check if there is already a window/tab open with the target URL
              for (var i = 0; i < windowClients.length; i++) {
                  var client = windowClients[i];
                  // If so, just focus it.
                  if (client.url === url && 'focus' in client) {
                      return client.focus();
                  }
              }
              // If not, then open the target URL in a new window/tab.
              if (clients.openWindow) {
                  return clients.openWindow(url);
              }
          })
  );
});
