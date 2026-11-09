// Shared helpers
(function () {
  const cfg = window.APP_CONFIG || {};
  window.sb = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_KEY);

  let lang = 'ar';
  try { lang = localStorage.getItem('lang') || 'ar'; } catch (e) {}
  const params = new URLSearchParams(location.search);
  if (params.get('lang') === 'en' || params.get('lang') === 'ar') lang = params.get('lang');

  window.App = {
    get lang() { return lang; },
    t(key) { return (I18N[lang] && I18N[lang][key]) || I18N.ar[key] || key; },
    setLang(l) {
      lang = l;
      try { localStorage.setItem('lang', l); } catch (e) {}
      App.applyLang();
      document.dispatchEvent(new CustomEvent('langchange'));
    },
    toggleLang() { App.setLang(lang === 'ar' ? 'en' : 'ar'); },
    applyLang() {
      document.documentElement.lang = lang;
      document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
      document.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = App.t(el.dataset.i18n); });
      document.querySelectorAll('[data-i18n-ph]').forEach(el => { el.placeholder = App.t(el.dataset.i18nPh); });
    },
    // pick localized field: obj.name_ar / obj.name_en
    L(obj, field) {
      if (!obj) return '';
      return obj[field + '_' + lang] || obj[field + '_' + (lang === 'ar' ? 'en' : 'ar')] || '';
    },
    money(v, currency) {
      const cur = currency || 'OMR';
      const digits = ['OMR', 'KWD', 'BHD', 'JOD'].includes(cur) ? 3 : 2;
      try {
        return new Intl.NumberFormat(lang === 'ar' ? 'ar-OM-u-nu-latn' : 'en-OM', {
          style: 'currency', currency: cur, minimumFractionDigits: digits, maximumFractionDigits: digits
        }).format(Number(v || 0));
      } catch (e) { return Number(v || 0).toFixed(digits) + ' ' + cur; }
    },
    esc(s) {
      return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    },
    toast(msg, kind) {
      let box = document.getElementById('toasts');
      if (!box) { box = document.createElement('div'); box.id = 'toasts'; document.body.appendChild(box); }
      const el = document.createElement('div');
      el.className = 'toast ' + (kind || '');
      el.textContent = msg;
      box.appendChild(el);
      setTimeout(() => el.classList.add('out'), 3200);
      setTimeout(() => el.remove(), 3700);
    },
    errMsg(e) {
      const m = (e && (e.message || e.error_description)) || String(e);
      const map = {
        RESTAURANT_CLOSED: 'closed_msg', RESTAURANT_SUSPENDED: 'suspended_msg', NOT_ALLOWED: 'not_admin', CARD_DECLINED: 'card_declined', USER_NOT_FOUND: 'user_not_found',
        CAR_PLATE_REQUIRED: 'plate_required', PHONE_REQUIRED: 'phone_required', OPTION_REQUIRED: 'option_required', BAD_OPTIONS: 'option_required', restaurants_payment_any: 'need_one_method', EMPTY_CART: 'empty_cart', ORDER_NOT_FOUND: 'not_found'
      };
      for (const k in map) if (m.includes(k)) return App.t(map[k]);
      if (m.includes('duplicate key') && m.includes('slug')) return lang === 'ar' ? 'هذا الرابط مستخدم، اختر رابط آخر' : 'This link is taken, choose another';
      return App.t('error') + ': ' + m;
    },
    optsText(opts) {
      if (!opts || !opts.length) return '';
      return ' (' + opts.map(o => App.esc(App.L(o, 'name'))).join(lang === 'ar' ? '، ' : ', ') + ')';
    },
    baseUrl() { return location.origin; },
    menuUrl(slug) { return location.origin + '/r/' + slug; },
    async requireAuth() {
      const { data } = await sb.auth.getSession();
      if (!data.session) { location.href = '/?login=1&next=' + encodeURIComponent(location.pathname + location.search); return null; }
      return data.session;
    },
    minutesLeft(iso, serverOffsetMs) {
      if (!iso) return null;
      const now = Date.now() + (serverOffsetMs || 0);
      return Math.ceil((new Date(iso).getTime() - now) / 60000);
    },
    timeAgo(iso) {
      const m = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
      return m <= 0 ? (lang === 'ar' ? 'الآن' : 'now') : (m + ' ' + App.t('min_short'));
    }
  };

  document.addEventListener('DOMContentLoaded', () => {
    App.applyLang();
    document.querySelectorAll('[data-lang-toggle]').forEach(b => b.addEventListener('click', App.toggleLang));
  });
})();
