# Denny Sentinel full-stack smoke notes

Session takeaways for future local verification runs on this repo:

- Always verify the current source against a fresh runtime. A stale long-lived server on port 3000 can be listening from earlier work; use a clean port (for example 3001) when you need to prove the current tree works.
- The admin panel is HTTP Basic protected. For smoke checks, send `Authorization: Basic base64(admin:admin)` or the configured credentials.
- Fast high-signal HTTP smoke sequence:
  1. `GET /` should return 200 and the app shell HTML.
  2. `GET /api/bots`, `/api/bots/config`, `/api/bots/:id`, `/api/stats`, `/api/orders`, `/api/payments` should return 200.
  3. Create a temporary category via `POST /api/categories`, update it, verify it appears in `GET /api/categories`, then delete it.
  4. Create a temporary product via `POST /api/products`, update it, verify it appears in `GET /api/products`, then delete it.
  5. `POST /api/bots/restart` should return success and the bot process should log a restart.
- The repo's legacy root `test/*.test.ts` suite is currently out of sync with the source tree and imports missing modules like `src/bot.ts`, `src/composer.ts`, `src/mod.ts`, and `src/platform.deno.ts`. Treat it as broken until repaired; do not use it as the sole evidence that the app is healthy.
- Build checks still matter: root `pnpm build` and `cd admin-panel && pnpm build` are useful gating checks before any smoke run.
