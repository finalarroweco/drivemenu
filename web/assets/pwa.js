// Installable app helpers (dashboard + cashier)
(function () {
  let deferred = null;
  const isStandalone = () => matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  const listeners = [];
  const notifyChange = () => listeners.forEach(fn => { try { fn(); } catch (e) {} });

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => { navigator.serviceWorker.register('/sw.js').catch(() => {}); });
  }
  window.addEventListener('beforeinstallprompt', e => { e.preventDefault(); deferred = e; notifyChange(); });
  window.addEventListener('appinstalled', () => { deferred = null; notifyChange(); try { App.toast(App.t('app_installed'), 'ok'); } catch (e) {} });

  let wakeLock = null;
  async function keepAwake() {
    try { if ('wakeLock' in navigator && !wakeLock) { wakeLock = await navigator.wakeLock.request('screen'); wakeLock.addEventListener('release', () => { wakeLock = null; }); } } catch (e) {}
  }
  document.addEventListener('visibilitychange', () => { if (!document.hidden && PWA._awake) keepAwake(); });

  window.PWA = {
    _awake: false,
    canInstall: () => !!deferred && !isStandalone(),
    isStandalone,
    onChange(fn) { listeners.push(fn); },
    async install() {
      if (deferred) { deferred.prompt(); const r = await deferred.userChoice.catch(() => null); deferred = null; notifyChange(); return r && r.outcome === 'accepted'; }
      const ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
      alert(App.t(ios ? 'install_ios_hint' : 'install_hint'));
      return false;
    },
    // wire a button: shown only when install is possible (or always on iOS Safari, with instructions)
    bindButton(btn) {
      if (!btn) return;
      const ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
      const sync = () => btn.classList.toggle('hidden', isStandalone() || !(deferred || ios));
      sync(); PWA.onChange(sync);
      btn.onclick = () => PWA.install();
    },
    async askNotify() {
      try { if ('Notification' in window && Notification.permission === 'default') await Notification.requestPermission(); } catch (e) {}
      return 'Notification' in window && Notification.permission === 'granted';
    },
    async notify(title, body, url, tag) {
      try {
        if (!('Notification' in window) || Notification.permission !== 'granted') return;
        const opts = { body, tag: tag || 'dm', renotify: true, icon: '/icons/icon-192.png', badge: '/icons/icon-192.png', data: { url: url || location.pathname + location.search }, requireInteraction: true, vibrate: [300, 120, 300] };
        const reg = 'serviceWorker' in navigator ? await navigator.serviceWorker.getRegistration() : null;
        if (reg) await reg.showNotification(title, opts); else new Notification(title, opts);
      } catch (e) {}
    },
    keepAwake() { PWA._awake = true; keepAwake(); }
  };
})();
