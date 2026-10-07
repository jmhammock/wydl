// Offline-first service worker.
//
// The app shell is served from cache immediately, then refreshed in the
// background. That way a returning client never waits on the network, but it
// also picks up a new elm.js or bank file on the very next visit instead
// of staying on a stale build forever. Bumping CACHE is still how you retire
// old files, but forgetting to bump no longer strands anyone on old content.

const CACHE = 'driver-test-v3';

const SHELL = [
  './',
  'index.html',
  'styles.css',
  'elm.js',
  'app.js',
  // BANKS-START
  'banks/mt.json',
  'banks/wy.json',
// BANKS-END
  'manifest.webmanifest',
  'icons/icon.svg',
  'icons/icon-180.png',
  'icons/icon-192.png',
  'icons/icon-512.png',
  'icons/icon-maskable-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((names) => Promise.all(
        names.filter((name) => name !== CACHE).map((name) => caches.delete(name))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;

  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) {
    return;
  }

  event.respondWith(respond(request));
});


async function respond(request) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(request);

  const refreshed = fetch(request).then((response) => {
    if (response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  });

  if (cached) {
    refreshed.catch(() => {});
    return cached;
  }

  try {
    return await refreshed;
  } catch (problem) {
    return new Response('Offline', {
      status: 503,
      headers: { 'Content-Type': 'text/plain' },
    });
  }
}
