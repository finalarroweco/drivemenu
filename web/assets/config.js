window.APP_CONFIG = {
  SUPABASE_URL: 'https://npkgoyfehoclurspzdvn.supabase.co',
  SUPABASE_KEY: 'sb_publishable_hF_KW3H6TQY7H7FnixEjgA_OthOhnhT',
  CONTACT_EMAIL: 'sales@drivemenu.app' // shown on /privacy and /terms
};

// Show load problems on screen instead of an endless spinner
(function () {
  var errors = [];
  function show(msg) {
    var root = document.getElementById('root');
    if (!root || !root.querySelector('.spinner')) return;
    root.innerHTML = '<div style="text-align:center;padding:30px 12px">' +
      '<p style="font-weight:700">تعذّر تحميل الصفحة · Could not load</p>' +
      '<button onclick="location.reload()" style="padding:10px 18px;border-radius:10px;border:0;background:#E2552B;color:#fff;font:inherit;font-weight:700">إعادة المحاولة · Retry</button>' +
      '<pre dir="ltr" style="white-space:pre-wrap;text-align:left;font-size:11px;color:#6F6A62;margin-top:16px">' +
      String(msg).replace(/</g, '&lt;') + '\n\n' + navigator.userAgent + '</pre></div>';
  }
  window.addEventListener('error', function (e) { errors.push((e.message || 'error') + ' @ ' + (e.filename || '') + ':' + (e.lineno || '')); show(errors.join('\n')); });
  window.addEventListener('unhandledrejection', function (e) { errors.push('promise: ' + (e.reason && (e.reason.message || e.reason))); show(errors.join('\n')); });
  setTimeout(function () {
    var why = typeof window.supabase === 'undefined' ? 'supabase library did not load (network/CDN blocked?)' : 'timeout after 15s (slow network?)';
    show((errors.length ? errors.join('\n') + '\n' : '') + why);
  }, 15000);
})();
