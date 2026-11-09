// DriveMenu service worker: installable app + notifications. No caching of API/data.
const OFFLINE_HTML = '<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DriveMenu</title>' +
  '<body style="font-family:system-ui,sans-serif;background:#FBF7F2;color:#1C1A17;display:grid;place-items:center;min-height:100vh;margin:0;text-align:center">' +
  '<div><div style="font-size:48px">📡</div><h2>لا يوجد اتصال بالإنترنت</h2><p>No internet connection</p>' +
  '<button onclick="location.reload()" style="padding:12px 20px;border:0;border-radius:12px;background:#E2552B;color:#fff;font-size:16px;font-weight:700">إعادة المحاولة · Retry</button></div></body></html>';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET' || req.mode !== 'navigate') return;
  e.respondWith(fetch(req).catch(() => new Response(OFFLINE_HTML, { headers: { 'Content-Type': 'text/html; charset=utf-8' } })));
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || '/cashier';
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
    for (const c of list) if (new URL(c.url).pathname === new URL(url, self.location.origin).pathname && 'focus' in c) return c.focus();
    return self.clients.openWindow(url);
  }));
});
