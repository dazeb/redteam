# Live app E2E verification pattern

Use this pattern when validating a current web/admin app rather than a static page.

## Sequence
1. Build the app.
2. Start the app on a fresh port if an older server may already be running.
3. Hit the health or home route directly with HTTP.
4. Check auth boundaries with direct requests when relevant.
5. Exercise API CRUD with temporary data.
6. Verify the UI with Playwright only after the live API is proven healthy.

## Why
This avoids wasting time debugging the browser when the app's backend or process lifecycle is already broken.

## Cleanup rule
If you create temporary records for testing, delete them in the same session before reporting success.
