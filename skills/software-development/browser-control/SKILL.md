---
name: browser-control
description: Operate a user's real browser through browser-harness/CDP with explicit tab activation, screenshot-first verification, and cautious setup/attach troubleshooting.
---

# Browser control

Use this skill when interacting with a user's running browser via browser-harness or a similar CDP-based harness.

## Core rules
- Prefer the user's real browser and real profile when the task depends on live sessions, cookies, or extensions.
- Read the repo's own `install.md`, `SKILL.md`, and core helper file before operating a harness checkout.
- Use `new_tab(url)` for first navigation; do not clobber the user's current tab with `goto_url(url)` unless that is explicitly intended.
- After opening a setup or verification tab, immediately activate it so the user can see the active tab.
- Verify after meaningful actions with `page_info()` and/or `capture_screenshot()`.
- Use screenshots to decide clicks before dropping to DOM-level work.
- Do not take irreversible visible actions without explicit user confirmation when the action has side effects outside the session.

## Setup / attach workflow
1. If a harness repo is involved, install it editable from a durable checkout so local edits take effect immediately.
2. Run the harness doctor/check command first to distinguish:
   - browser not running
   - daemon not attached
   - remote debugging not enabled
3. If Chrome is already running but the harness cannot attach, open the browser's remote-debugging settings page in the real Chrome instance and ask the user to enable remote debugging and accept any popup.
4. Once attached, open a visible demo tab and activate it so the user can confirm the connection.

## Interaction pattern
- Start with a screenshot or `page_info()`.
- Click by coordinates when the target is visible.
- Re-screenshot after the click before assuming success.
- Use `switch_tab()` whenever the user needs a specific visible tab to become active.
- For sites with login state, check whether the user is authenticated before attempting actions that modify account state.

## Common demo flow
When demonstrating browser attachment on a fresh session:
- open the target repo or site in a new tab
- activate the tab
- if the user is logged into the target service, ask before any account-affecting action
- if the user is not logged in, navigate to the public landing page instead

## Bot Detection & Cloudflare

When a site serves a Cloudflare Turnstile challenge (checkbox or CAPTCHA):
- Click the checkbox via snapshot ref, then immediately `browser_navigate` to the target URL (e.g. `/login`) — the cached Turnstile token carries through.
- See `references/cloudflare-bypass.md` for the full technique, failure modes, and when to escalate to residential proxies or Camoufox.

## References
- `references/browser-harness-setup.md` — distilled attach/setup notes, WSL/Windows Chrome popup workaround, and troubleshooting cues.
- `references/cloudflare-bypass.md` — Cloudflare Turnstile bypass via built-in browser tools (checkbox + direct URL).
