// Offline support: always try the network first for this site's own files (so updates arrive right away),
// fall back to the saved copy when the bowling alley has no signal.
// Fonts and icons from the CDN are versioned, so they are served from the saved copy first.
const CACHE = 'bowling-diary-v3';
const ASSETS = ['./', './index.html', './help.html', './signup.html', './manifest.webmanifest', './icons/icon-192.png', './icons/icon-512.png', './icons/apple-touch-icon.png'];
const CDN_KEEP = [/^https:\/\/cdn\.jsdelivr\.net\/gh\/orioncactus\/pretendard@/, /^https:\/\/cdn\.jsdelivr\.net\/npm\/@tabler\/icons-webfont@/];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => Promise.all(ASSETS.map(a => c.add(a).catch(() => {})))).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  if (CDN_KEEP.some(r => r.test(e.request.url))) {
    e.respondWith(caches.match(e.request).then(hit => hit || fetch(e.request).then(res => {
      if (res.ok || res.type === 'opaque') { const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); }
      return res;
    })));
    return;
  }
  // only this site's own files; AI requests and the AI library go straight to the network
  if (url.origin !== self.location.origin) return;
  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); }
        return res;
      })
      .catch(() => caches.match(e.request).then(hit => hit || caches.match('./index.html')))
  );
});
