# Denny Sentinel clean E2E and cleanup sweep

Use this when doing a full-app sweep of the Denny Sentinel bot/admin panel repo.

## Reliable sequence
1. Build both codepaths first.
   - root: `pnpm build`
   - admin-panel: `cd admin-panel && pnpm build`
2. Start the live stack on a fresh port instead of trusting an old process.
   - Prefer a disposable port such as 3001 for smoke work.
   - If a repo helper script exists, make sure it streams logs live and cleans up idempotently.
3. Verify the auth boundary directly over HTTP before browser/UI work.
   - Example: authenticated `curl` against `/`, `/api/bots`, `/api/stats`, `/api/products`, `/api/categories`, `/api/orders`, `/api/payments`.
4. Exercise real CRUD with disposable fixtures.
   - create a temp category
   - update it
   - create a temp product
   - update it
   - delete both
   - confirm the API returns expected status codes and the UI/API surfaces stay coherent
5. Verify restart signaling if the app uses a file flag or hot-reload trigger.
6. For bot-backed systems, verify Telegram/API credential health directly when polling shows repeated 401s.
   - Recheck the stored token against the provider before assuming an app bug.
7. Only then decide whether browser-level UI automation is still needed.

## Pitfalls observed in this repo
- Old root test files can be stale and import modules from a previous architecture.
  - If imports are missing from the current source tree, treat the suite as a cleanup task, not a verification gate.
- A live server from an older session may still answer requests.
  - Always confirm you are hitting the current source tree and a clean port.
- CRUD smoke tests should clean up their own fixtures.
  - Leaving temp categories/products behind makes later sweeps noisy.
- If the bot logs repeated `401 Unauthorized` polling errors, verify the token itself rather than digging through UI paths first.

## Good evidence to capture
- build output for both trees
- HTTP status codes for the authenticated endpoints
- exact CRUD result summary
- restart signal success
- any bot/provider credential verification result

## Related skill pointers
- See the parent skill for general browser and Playwright setup.
- Use this reference when the task is a repo-wide smoke sweep rather than a single page check.
