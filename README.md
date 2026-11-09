# DriveMenu · درايف منيو

منصة طلب من السيارة للمطاعم والكافيهات: الزبون بيمسح QR، بيطلب من المنيو مع معلومات سيارته، والطلب بيوصل مباشرة على شاشة الكاشير مع وقت تجهيز تقديري.

Curbside ordering platform for restaurants: scan a QR code, order from the car, and the order lands live on the cashier screen with an estimated prep time.

## Structure

```
web/                 Static site (deployed to Vercel, no build step)
  index.html         Landing + sign in / sign up
  menu.html          Customer menu, cart, pre-order time, coupons, payment   (/r/:slug)
  order.html         Customer order tracking                                (/o/:id)
  dashboard.html     Restaurant dashboard: menu, QR, orders, reports, coupons, staff, settings
  cashier.html       Live cashier board
  admin.html         Platform admin
  privacy.html, terms.html
  manifest.webmanifest, sw.js, icons/   Installable app (PWA)
  assets/
    config.js        Supabase URL + publishable key
    common.js        Shared helpers (App.*)
    i18n.js          Arabic / English strings
    i18n-extra.js    Strings for pre-orders, coupons, install
    reports.js       Reports UI (owner + platform admin)
    pwa.js           Install button, notifications, wake lock
    app.css
  vercel.json        Clean URLs, rewrites, headers
supabase/migrations/ Database schema, RLS policies and RPC functions, in order
```

## Stack

- **Supabase**: Postgres, Row Level Security, RPC functions (all prices, discounts and limits are computed in the database), Realtime, Storage (`menu-images`), Auth.
- **Vercel**: static hosting at https://drivemenu.app

## Deploy

1. Database: run the files in `supabase/migrations/` in order on a fresh Supabase project, then add a platform admin
   (see the comment in `005_platform_admin.sql`).
2. Put the project URL and publishable key in `web/assets/config.js`.
3. Deploy the `web/` folder to Vercel (root directory = `web`, no build command, framework = Other).
   The Vercel project is connected to this repository: every push to `main` deploys to production.
4. Supabase → Authentication → URL Configuration: set the Site URL to the production domain and add it to Redirect URLs.

## Payments

Card payments currently run in **test mode** (`pay_order_test`). A live gateway still needs to be connected.
