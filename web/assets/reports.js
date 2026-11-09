// Reports (owner + platform admin). Depends on: sb, App, I18N
(function () {
  Object.assign(I18N.ar, {
    tab_reports: 'التقارير', rp_today: 'اليوم', rp_yesterday: 'أمس', rp_7d: 'آخر 7 أيام', rp_30d: 'آخر 30 يوم', rp_month: 'هذا الشهر',
    rp_custom: 'مخصص', rp_from: 'من', rp_to: 'إلى', rp_apply: 'عرض', rp_export: 'تصدير Excel', rp_sales: 'إجمالي المبيعات',
    rp_orders: 'عدد الطلبات', rp_avg: 'متوسط قيمة الطلب', rp_cancelled: 'الطلبات الملغية', rp_items_sold: 'الأصناف المباعة',
    rp_vs_prev: 'عن الفترة السابقة', rp_no_prev: 'لا توجد بيانات للفترة السابقة', rp_daily: 'المبيعات يوماً بيوم', rp_hours: 'ساعات الذروة',
    rp_weekdays: 'أيام الأسبوع', rp_peak: 'الذروة', rp_top_items: 'الأصناف الأكثر مبيعاً', rp_top_options: 'الإضافات الأكثر طلباً',
    rp_item: 'الصنف', rp_qty: 'الكمية', rp_amount: 'المبلغ', rp_ops: 'أداء التجهيز', rp_avg_prep: 'متوسط وقت التجهيز الفعلي',
    rp_avg_est: 'متوسط الوقت المقدّر', rp_on_time: 'جاهز بالوقت', rp_total_wait: 'متوسط انتظار الزبون', rp_measured: 'محسوبة من {n} طلب',
    rp_payments: 'طرق الدفع', rp_cash: 'كاش', rp_card: 'بطاقة', rp_cash_collected: 'كاش تم تحصيله', rp_cash_pending: 'كاش لم يُحصّل بعد',
    rp_orders_n: '{n} طلب', rp_empty: 'ما في طلبات بهالفترة', rp_min: 'د', rp_restaurant: 'المطعم', rp_last: 'آخر طلب',
    rp_platform: 'تقرير المنصة', rp_orders_day: 'الطلبات يومياً (كل المطاعم)', rp_inactive: 'بدون طلبات بهالفترة',
    rp_discounts: 'الخصومات (كوبونات)', rp_scheduled: 'طلبات مجدولة', rp_csv_cols: 'رقم الطلب,التاريخ والوقت,الحالة,طريقة الدفع,حالة الدفع,المجموع,الخصم,الكوبون,الإجمالي,العملة,موعد الاستلام,الأصناف,اسم الزبون,الهاتف,السيارة,اللوحة,الموقف,الوقت المقدر (د),وقت التجهيز الفعلي (د)',
    rp_status_completed: 'مكتمل', rp_status_ready: 'جاهز', rp_status_preparing: 'قيد التحضير', rp_status_pending: 'جديد', rp_status_cancelled: 'ملغي',
    rp_paid: 'مدفوع', rp_unpaid: 'غير مدفوع', rp_range_err: 'اختر فترة صحيحة (حتى سنة)'
  });
  Object.assign(I18N.en, {
    tab_reports: 'Reports', rp_today: 'Today', rp_yesterday: 'Yesterday', rp_7d: 'Last 7 days', rp_30d: 'Last 30 days', rp_month: 'This month',
    rp_custom: 'Custom', rp_from: 'From', rp_to: 'To', rp_apply: 'Show', rp_export: 'Export Excel', rp_sales: 'Total sales',
    rp_orders: 'Orders', rp_avg: 'Average order', rp_cancelled: 'Cancelled', rp_items_sold: 'Items sold',
    rp_vs_prev: 'vs previous period', rp_no_prev: 'No data for previous period', rp_daily: 'Daily sales', rp_hours: 'Peak hours',
    rp_weekdays: 'Days of week', rp_peak: 'Peak', rp_top_items: 'Top items', rp_top_options: 'Top add-ons',
    rp_item: 'Item', rp_qty: 'Qty', rp_amount: 'Amount', rp_ops: 'Prep performance', rp_avg_prep: 'Avg actual prep time',
    rp_avg_est: 'Avg estimated time', rp_on_time: 'Ready on time', rp_total_wait: 'Avg customer wait', rp_measured: 'Based on {n} orders',
    rp_payments: 'Payment methods', rp_cash: 'Cash', rp_card: 'Card', rp_cash_collected: 'Cash collected', rp_cash_pending: 'Cash not yet collected',
    rp_orders_n: '{n} orders', rp_empty: 'No orders in this period', rp_min: 'min', rp_restaurant: 'Restaurant', rp_last: 'Last order',
    rp_platform: 'Platform report', rp_orders_day: 'Orders per day (all restaurants)', rp_inactive: 'No orders in this period',
    rp_discounts: 'Discounts (coupons)', rp_scheduled: 'Scheduled orders', rp_csv_cols: 'Order #,Date & time,Status,Payment method,Payment status,Subtotal,Discount,Coupon,Total,Currency,Pickup time,Items,Customer,Phone,Car,Plate,Spot,Estimated (min),Actual prep (min)',
    rp_status_completed: 'Completed', rp_status_ready: 'Ready', rp_status_preparing: 'Preparing', rp_status_pending: 'New', rp_status_cancelled: 'Cancelled',
    rp_paid: 'Paid', rp_unpaid: 'Unpaid', rp_range_err: 'Pick a valid range (up to 1 year)'
  });

  const css = `
  .rp-bar{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-bottom:16px}
  .rp-bar .btn.on{background:var(--ink);border-color:var(--ink);color:#fff}
  .rp-bar input[type=date]{width:auto;padding:7px 10px}
  .rp-kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:12px;margin-bottom:16px}
  .rp-kpi b{display:block;font-size:1.55rem;margin:2px 0}
  .rp-delta{font-size:.8rem;font-weight:600}
  .rp-delta.up{color:var(--ok)} .rp-delta.down{color:var(--bad)}
  .rp-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:16px}
  .rp-grid .wide{grid-column:1/-1}
  .rp-chart svg{width:100%;height:auto;display:block}
  .rp-chart .lbl{font-size:10px;fill:var(--muted)}
  .rp-meter{height:10px;border-radius:99px;background:#F1ECE5;overflow:hidden;margin-top:6px}
  .rp-meter i{display:block;height:100%;background:var(--brand);border-radius:99px}
  .rp-stat{display:flex;justify-content:space-between;align-items:baseline;padding:10px 0;border-bottom:1px solid var(--line)}
  .rp-stat:last-child{border-bottom:0}
  .rp-stat b{font-size:1.15rem}
  .rp-rank{display:inline-grid;place-items:center;width:24px;height:24px;border-radius:7px;background:#F1ECE5;font-size:.8rem;font-weight:700;margin-inline-end:8px}
  @media(max-width:820px){.rp-grid{grid-template-columns:1fr}}`;
  const st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);

  const t = k => App.t(k), esc = App.esc;
  const TZ = 'Asia/Muscat';
  const iso = d => d.toLocaleDateString('en-CA', { timeZone: TZ });
  const todayStr = () => iso(new Date());
  const addDays = (s, n) => { const d = new Date(s + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };
  const fmtNum = n => Number(n || 0).toLocaleString(App.lang === 'ar' ? 'ar-OM-u-nu-latn' : 'en-US');
  const dayLabel = s => new Date(s + 'T12:00:00Z').toLocaleDateString(App.lang === 'ar' ? 'ar-OM-u-nu-latn' : 'en-GB', { day: 'numeric', month: 'short', timeZone: 'UTC' });
  const weekdayNames = () => App.lang === 'ar'
    ? ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت']
    : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  function presetRange(p) {
    const td = todayStr();
    if (p === 'today') return [td, td];
    if (p === 'yesterday') { const y = addDays(td, -1); return [y, y]; }
    if (p === '7d') return [addDays(td, -6), td];
    if (p === '30d') return [addDays(td, -29), td];
    if (p === 'month') return [td.slice(0, 8) + '01', td];
    return null;
  }

  function rangeBar(state, extra) {
    const ps = ['today', 'yesterday', '7d', '30d', 'month'];
    return `<div class="rp-bar">
      ${ps.map(p => `<button class="btn sm ${state.preset === p ? 'on' : ''}" data-rp="${p}">${t('rp_' + p)}</button>`).join('')}
      <span class="small muted">${t('rp_from')}</span><input type="date" id="rpFrom" value="${state.from}" max="${todayStr()}">
      <span class="small muted">${t('rp_to')}</span><input type="date" id="rpTo" value="${state.to}" max="${todayStr()}">
      <button class="btn sm" id="rpApply">${t('rp_apply')}</button>
      <div class="grow"></div>${extra || ''}
    </div>`;
  }
  function bindRange(root, state, reload) {
    root.querySelectorAll('[data-rp]').forEach(b => b.onclick = () => {
      state.preset = b.dataset.rp; [state.from, state.to] = presetRange(state.preset); reload();
    });
    const ap = root.querySelector('#rpApply');
    if (ap) ap.onclick = () => {
      const f = root.querySelector('#rpFrom').value, to = root.querySelector('#rpTo').value;
      if (!f || !to || to < f || (new Date(to) - new Date(f)) / 864e5 > 366) { App.toast(t('rp_range_err'), 'bad'); return; }
      state.preset = 'custom'; state.from = f; state.to = to; reload();
    };
  }

  function delta(cur, prev, invert) {
    cur = Number(cur || 0); prev = Number(prev || 0);
    if (!prev) return `<span class="small muted">${cur ? t('rp_no_prev') : '&nbsp;'}</span>`;
    const pct = Math.round((cur - prev) / prev * 100);
    const good = invert ? pct <= 0 : pct >= 0;
    return `<span class="rp-delta ${pct === 0 ? '' : good ? 'up' : 'down'}" dir="ltr">${pct > 0 ? '▲' : pct < 0 ? '▼' : '•'} ${Math.abs(pct)}%</span> <span class="small muted">${t('rp_vs_prev')}</span>`;
  }

  // vertical bar chart (SVG). values: numbers; labels: strings; fmt: tooltip formatter
  function bars(values, labels, opts) {
    opts = opts || {};
    const W = 640, H = opts.h || 200, padB = 22, padT = 10, n = values.length || 1;
    const max = Math.max(1, ...values);
    const gap = n > 40 ? 1 : n > 20 ? 2 : 4, bw = (W - gap * (n - 1)) / n;
    const peak = values.indexOf(Math.max(...values));
    const every = Math.ceil(n / (opts.maxLabels || 10));
    const rtl = document.documentElement.dir === 'rtl';
    let s = `<svg viewBox="0 0 ${W} ${H}" role="img" preserveAspectRatio="none" style="direction:ltr">`;
    s += `<line x1="0" x2="${W}" y1="${H - padB + .5}" y2="${H - padB + .5}" stroke="var(--line)"/>`;
    values.forEach((v, i) => {
      const idx = rtl && opts.mirror ? n - 1 - i : i;
      const x = idx * (bw + gap), h = v ? Math.max(2, (H - padB - padT) * v / max) : 0;
      const col = v && i === peak ? 'var(--brand)' : 'var(--brand-soft)';
      const stroke = v && i !== peak ? ' stroke="#F2B9A6" stroke-width="1"' : '';
      s += `<rect x="${x.toFixed(1)}" y="${(H - padB - h).toFixed(1)}" width="${Math.max(1, bw).toFixed(1)}" height="${h.toFixed(1)}" rx="${Math.min(4, bw / 3).toFixed(1)}" fill="${col}"${stroke}><title>${esc(labels[i])}: ${esc(opts.fmt ? opts.fmt(v) : v)}</title></rect>`;
      if (i % every === 0 || n <= 12) s += `<text class="lbl" x="${(x + bw / 2).toFixed(1)}" y="${H - 6}" text-anchor="middle">${esc(opts.short ? opts.short(labels[i], i) : labels[i])}</text>`;
    });
    return s + '</svg>';
  }

  function rankTable(rows, cur, withGroup) {
    if (!rows.length) return `<div class="empty small">—</div>`;
    return `<table><thead><tr><th>${t('rp_item')}</th><th>${t('rp_qty')}</th><th>${t('rp_amount')}</th></tr></thead><tbody>
      ${rows.map((r, i) => `<tr><td><span class="rp-rank num">${i + 1}</span>${esc(App.L(r, 'name'))}${withGroup && App.L(r, 'group') ? ` <span class="small muted">· ${esc(App.L(r, 'group'))}</span>` : ''}</td>
        <td class="num"><b>${fmtNum(r.qty)}</b></td><td class="num">${App.money(r.sales, cur)}</td></tr>`).join('')}
    </tbody></table>`;
  }

  function csvDownload(name, header, rows) {
    const q = v => { const s = v == null ? '' : String(v); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
    const body = [header].concat(rows.map(r => r.map(q).join(','))).join('\r\n');
    const blob = new Blob(['\uFEFF' + body], { type: 'text/csv;charset=utf-8' });
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = name;
    document.body.appendChild(a); a.click(); setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 500);
  }

  // ---------------- owner ----------------
  const ownerState = { preset: '7d', from: null, to: null };
  async function renderOwner(el, R) {
    if (!ownerState.from) [ownerState.from, ownerState.to] = presetRange(ownerState.preset);
    const S = ownerState;
    el.innerHTML = rangeBar(S, `<button class="btn sm" id="rpCsv">⬇ ${t('rp_export')}</button>`) + '<div id="rpBody"><div class="spinner"></div></div>';
    bindRange(el, S, () => renderOwner(el, R));
    el.querySelector('#rpCsv').onclick = async e => {
      const b = e.currentTarget; b.disabled = true;
      const { data, error } = await sb.rpc('owner_report_rows', { p_restaurant: R.id, p_from: S.from, p_to: S.to });
      b.disabled = false;
      if (error) { App.toast(App.errMsg(error), 'bad'); return; }
      const stt = s => t('rp_status_' + s) || s;
      csvDownload(`drivemenu-${R.slug}-${S.from}_${S.to}.csv`, t('rp_csv_cols'), (data || []).map(r => [
        r.order_number, String(r.created_local).replace('T', ' ').slice(0, 16), stt(r.status), t('rp_' + r.payment_method) || r.payment_method,
        r.payment_status === 'paid' ? t('rp_paid') : t('rp_unpaid'), r.subtotal, r.discount, r.coupon_code, r.total, r.currency, r.scheduled_local ? String(r.scheduled_local).replace('T', ' ').slice(0, 16) : '', r.items, r.customer_name, r.customer_phone,
        r.car, r.car_plate, r.parking_spot, r.estimated_minutes, r.actual_minutes]));
    };
    const { data: D, error } = await sb.rpc('owner_report', { p_restaurant: R.id, p_from: S.from, p_to: S.to });
    const body = el.querySelector('#rpBody'); if (!body) return;
    if (error) { body.innerHTML = `<div class="empty">${esc(App.errMsg(error))}</div>`; return; }
    const K = D.kpi, P = D.prev, cur = D.currency, O = D.ops, Y = D.payments;
    const money = v => App.money(v, cur);
    const kpis = `<div class="rp-kpis">
      <div class="card flat rp-kpi"><span class="small muted">${t('rp_sales')}</span><b class="num">${money(K.sales)}</b>${delta(K.sales, P.sales)}</div>
      <div class="card flat rp-kpi"><span class="small muted">${t('rp_orders')}</span><b class="num">${fmtNum(K.orders)}</b>${delta(K.orders, P.orders)}</div>
      <div class="card flat rp-kpi"><span class="small muted">${t('rp_avg')}</span><b class="num">${money(K.avg)}</b>${delta(K.avg, P.avg)}</div>
      <div class="card flat rp-kpi"><span class="small muted">${t('rp_cancelled')}</span><b class="num">${fmtNum(K.cancelled)} <span class="small muted" dir="ltr">(${K.cancel_rate}%)</span></b>${delta(K.cancelled, P.cancelled, true)}</div>
      ${Number(K.discounts) ? `<div class="card flat rp-kpi"><span class="small muted">${t('rp_discounts')}</span><b class="num">${money(K.discounts)}</b><span class="small muted">${t('rp_orders_n').replace('{n}', fmtNum(K.coupon_orders))}</span></div>` : ''}
      ${Number(K.scheduled) ? `<div class="card flat rp-kpi"><span class="small muted">${t('rp_scheduled')}</span><b class="num">${fmtNum(K.scheduled)}</b><span class="small muted" dir="ltr">${Math.round(K.scheduled / Math.max(K.orders, 1) * 100)}%</span></div>` : ''}
    </div>`;
    if (!K.orders && !K.cancelled) { body.innerHTML = kpis + `<div class="card empty">${t('rp_empty')}</div>`; return; }

    const daily = D.daily || [];
    const hours = D.hours || [], wd = D.weekdays || [];
    const peakH = hours.indexOf(Math.max(...hours));
    const hLabel = h => (App.lang === 'ar' ? (h % 12 || 12) + (h < 12 ? 'ص' : 'م') : (h % 12 || 12) + (h < 12 ? 'a' : 'p'));
    const peakW = wd.indexOf(Math.max(...wd));
    const wn = weekdayNames();
    const ord = n => t('rp_orders_n').replace('{n}', fmtNum(n));
    const m = v => v == null ? '—' : fmtNum(v) + ' ' + t('rp_min');
    const onTime = O.on_time_pct;
    const totPay = Number(Y.cash_sales) + Number(Y.card_sales) || 1;

    body.innerHTML = kpis + `
    <div class="rp-grid">
      <div class="card rp-chart wide"><div class="row spread"><h3 style="margin:0">${t('rp_daily')}</h3><span class="small muted">${t('rp_items_sold')}: <b class="num">${fmtNum(K.items_sold)}</b></span></div>
        ${daily.length > 1 ? bars(daily.map(d => Number(d.sales)), daily.map(d => dayLabel(d.d) + ' · ' + ord(d.orders)), { fmt: money, short: (l, i) => dayLabel(daily[i].d), mirror: true, maxLabels: 8 })
          : `<div class="row spread" style="padding:20px 0"><span class="muted">${dayLabel(daily[0].d)}</span><b class="num">${money(daily[0].sales)} · ${ord(daily[0].orders)}</b></div>`}
      </div>
      <div class="card rp-chart"><div class="row spread"><h3 style="margin:0">${t('rp_hours')}</h3><span class="badge brand">${t('rp_peak')}: ${hLabel(peakH)}–${hLabel((peakH + 1) % 24)}</span></div>
        ${bars(hours, hours.map((_, h) => hLabel(h) + '–' + hLabel((h + 1) % 24)), { fmt: ord, short: (_, h) => hLabel(h), maxLabels: 8, h: 170, mirror: true })}
      </div>
      <div class="card rp-chart"><div class="row spread"><h3 style="margin:0">${t('rp_weekdays')}</h3><span class="badge brand">${t('rp_peak')}: ${wn[peakW]}</span></div>
        ${bars(wd, wn, { fmt: ord, mirror: true, h: 170 })}
      </div>
      <div class="card"><h3>${t('rp_top_items')}</h3>${rankTable(D.top_items || [], cur)}</div>
      <div class="card"><h3>${t('rp_top_options')}</h3>${rankTable(D.top_options || [], cur, true)}</div>
      <div class="card"><h3 style="margin-bottom:4px">${t('rp_ops')}</h3>
        <div class="small muted">${t('rp_measured').replace('{n}', fmtNum(O.measured))}</div>
        <div class="rp-stat"><span>${t('rp_avg_prep')}</span><b class="num">${m(O.avg_prep)}</b></div>
        <div class="rp-stat"><span>${t('rp_avg_est')}</span><b class="num">${m(O.avg_estimated)}</b></div>
        <div class="rp-stat"><span>${t('rp_total_wait')}</span><b class="num">${m(O.avg_total_wait)}</b></div>
        <div class="rp-stat" style="display:block"><div class="row spread"><span>${t('rp_on_time')}</span><b class="num" dir="ltr">${onTime == null ? '—' : onTime + '%'}</b></div>
          ${onTime == null ? '' : `<div class="rp-meter"><i style="width:${onTime}%;background:${onTime >= 80 ? 'var(--ok)' : onTime >= 60 ? 'var(--warn)' : 'var(--bad)'}"></i></div>`}</div>
      </div>
      <div class="card"><h3>${t('rp_payments')}</h3>
        <div class="rp-stat" style="display:block"><div class="row spread"><span>💵 ${t('rp_cash')} <span class="small muted">· ${ord(Y.cash_orders)}</span></span><b class="num">${money(Y.cash_sales)}</b></div>
          <div class="rp-meter"><i style="width:${Math.round(Y.cash_sales / totPay * 100)}%"></i></div></div>
        <div class="rp-stat" style="display:block"><div class="row spread"><span>💳 ${t('rp_card')} <span class="small muted">· ${ord(Y.card_orders)}</span></span><b class="num">${money(Y.card_sales)}</b></div>
          <div class="rp-meter"><i style="width:${Math.round(Y.card_sales / totPay * 100)}%;background:var(--info)"></i></div></div>
        <div class="rp-stat"><span>${t('rp_cash_collected')}</span><b class="num">${money(Y.cash_collected)}</b></div>
        ${Number(Y.cash_uncollected) ? `<div class="rp-stat"><span style="color:var(--warn)">${t('rp_cash_pending')}</span><b class="num" style="color:var(--warn)">${money(Y.cash_uncollected)}</b></div>` : ''}
      </div>
    </div>`;
  }

  // ---------------- platform admin ----------------
  const adminState = { preset: '30d', from: null, to: null };
  async function renderAdmin(el) {
    if (!adminState.from) [adminState.from, adminState.to] = presetRange(adminState.preset);
    const S = adminState;
    el.innerHTML = `<div class="card"><h2 style="margin-top:0">${t('rp_platform')}</h2>${rangeBar(S)}<div id="rpABody"><div class="spinner"></div></div></div>`;
    bindRange(el, S, () => renderAdmin(el));
    const { data: D, error } = await sb.rpc('admin_report', { p_from: S.from, p_to: S.to });
    const body = el.querySelector('#rpABody'); if (!body) return;
    if (error) { body.innerHTML = `<div class="empty">${esc(App.errMsg(error))}</div>`; return; }
    const daily = D.daily || [];
    const ord = n => t('rp_orders_n').replace('{n}', fmtNum(n));
    const fmtD = s => s ? new Date(s).toLocaleDateString(App.lang === 'ar' ? 'ar-OM-u-nu-latn' : 'en-GB', { dateStyle: 'medium' }) : '—';
    body.innerHTML = `
      ${daily.length > 1 ? `<div class="rp-chart" style="margin-bottom:14px"><div class="small muted" style="margin-bottom:6px">${t('rp_orders_day')}</div>
        ${bars(daily.map(d => d.orders), daily.map(d => dayLabel(d.d)), { fmt: ord, mirror: true, maxLabels: 8, h: 150 })}</div>` : ''}
      <div style="overflow-x:auto"><table><thead><tr><th>${t('rp_restaurant')}</th><th>${t('rp_orders')}</th><th>${t('rp_sales')}</th><th>${t('rp_avg')}</th><th>${t('rp_cancelled')}</th><th>${t('rp_last')}</th></tr></thead><tbody>
      ${(D.restaurants || []).map(r => `<tr class="${r.is_suspended ? 'off' : ''}">
        <td><b>${esc(App.L(r, 'name'))}</b>${!r.orders ? ` <span class="badge warn">${t('rp_inactive')}</span>` : ''}</td>
        <td class="num">${fmtNum(r.orders)}</td><td class="num">${App.money(r.sales, r.currency)}</td><td class="num">${App.money(r.avg, r.currency)}</td>
        <td class="num">${fmtNum(r.cancelled)}</td><td class="small num">${fmtD(r.last_order_at)}</td></tr>`).join('') || `<tr><td colspan="6" class="empty">—</td></tr>`}
      </tbody></table></div>`;
  }

  window.Reports = { renderOwner, renderAdmin };
})();
