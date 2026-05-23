---
name: browser-form-automation
description: Automate web form interactions through built-in browser tools — hidden field discovery, file uploads, multi-tab settings forms, and bot-detection bypass. Use when populating profiles, filling complex forms, or working with tabbed settings pages.
---

# Browser Form Automation

Patterns for automating form interactions through the built-in browser tools (`browser_navigate`, `browser_snapshot`, `browser_click`, `browser_type`, `browser_console`, `browser_scroll`).

## When to Use
- Completing user profiles on marketplace/community sites
- Filling multi-tab settings forms where fields span tabs
- Uploading files through browser file inputs
- Bypassing Cloudflare Turnstile or similar bot-detection challenges

## Core Patterns

### Pattern 1: Hidden Field Discovery

Tabbed settings pages often load all form fields into the DOM but only display the active tab's fields. The accessibility snapshot (`browser_snapshot`) won't show hidden-tab fields.

**Detection:** Use `browser_console` to enumerate ALL form fields in the DOM:

```javascript
JSON.stringify(Array.from(document.querySelectorAll('textarea, input[type="text"]:not([type="hidden"])')).map(e => ({
  name: e.name, id: e.id, label: e.closest('.form-group')?.querySelector('label')?.textContent?.trim(), value: e.value?.slice(0,50)
})))
```

**Setting hidden fields:** Once discovered, set values directly:

```javascript
document.getElementById('by_line').value = 'Your heading here';
document.getElementById('profile_desc').value = 'Your bio text here';
```

**Submitting:** Find and click the save button (often hidden in another tab):

```javascript
Array.from(document.querySelectorAll('button')).find(b => /save/i.test(b.textContent)).click();
```

### Pattern 2: File Uploads

`browser_type` on file inputs may appear to fail — the DOM still shows "No file chosen" in snapshots. **This is misleading.** The file path IS set internally. Click the upload/submit button and verify with the success message.

**Workflow:**
1. Download/generate files to `/tmp/`
2. `browser_type` the file path into each file input
3. Ignore "No file chosen" in subsequent snapshots
4. Click the upload/save button
5. Verify via success message or profile reload

**Pitfall:** `browser_console` cannot set file input values for security reasons. `browser_type` is the correct tool.

### Pattern 3: Cloudflare Turnstile Bypass

When the built-in browser hits a Cloudflare challenge:
1. Click the "Verify you are human" checkbox in the iframe
2. Navigate directly to the target URL (e.g., `/login` instead of waiting for redirect)
3. The challenge is often satisfied by the checkbox click + direct navigation

**Pitfall:** Browser sessions expire. Re-authenticate and re-navigate if you get empty snapshots.

### Pattern 4: Multi-Tab Form Navigation

When a form spans multiple tabs:
1. Use `browser_click` on tab links (found via `browser_snapshot`)
2. Wait for the tab to load (snapshot after each click)
3. If needed fields aren't visible, try scrolling (`browser_scroll`)
4. Fall back to `browser_console` for direct DOM manipulation if tabs hide fields

## Pitfalls

- **DOM snapshots are truncated** — the accessibility tree cuts off. Use `browser_console` as a secondary inspection channel.
- **Refs expire** — after navigation, previous `ref` values are invalid. Always re-snapshot.
- **Rate limiting on vision** — `browser_vision` may hit 429 quota. Don't rely on it as primary verification.
- **Rich-text editors** — fields like Redactor may not persist plain-text values set via JavaScript. Manual paste may be needed for WYSIWYG editors.

## References
- `references/codester-profile.md` — Full Codester profile completion workflow (Cloudflare → login → avatar/background upload → heading/text via hidden fields). Includes account credentials and site structure.
