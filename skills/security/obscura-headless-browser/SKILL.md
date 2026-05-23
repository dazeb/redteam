---
name: obscura-headless-browser
description: Use Obscura, the lightweight Rust headless browser, for web scraping, automation, and CDP-based agent browsing
---

# Obscura Headless Browser

Obscura is an open-source headless browser written in Rust (V8 engine). It's a drop-in replacement for headless Chrome with CDP support — works with Puppeteer/Playwright.

## Installation

Binary installed at `~/.local/bin/obscura`. Single binary, no dependencies.

## Basic Usage

### Fetch a page

```bash
# Get page title
obscura fetch https://example.com --eval "document.title"

# Dump all links
obscura fetch https://example.com --dump links

# Render JS and dump HTML
obscura fetch https://news.ycombinator.com --dump html

# Wait for dynamic content
obscura fetch https://example.com --wait-until networkidle0
```

### Start CDP Server (for Puppeteer/Playwright)

```bash
# Basic server
obscura serve --port 9222

# With proxy
obscura serve --port 9222 --proxy http://proxy:8080
```

### Parallel Scraping

```bash
obscura scrape url1 url2 url3 \
  --concurrency 25 \
  --eval "document.querySelector('h1').textContent" \
  --format json
```

## Puppeteer Integration

```javascript
import puppeteer from 'puppeteer-core';
const browser = await puppeteer.connect({
  browserWSEndpoint: 'ws://127.0.0.1:9222/devtools/browser',
});
const page = await browser.newPage();
await page.goto('https://example.com');
const title = await page.evaluate(() => document.title);
console.log(title);
await browser.disconnect();
```

## Stealth Mode (built from source with `--features stealth`)

- Per-session fingerprint randomization (GPU, screen, canvas, audio, battery)
- Realistic `navigator.userAgentData` (Chrome 145, high-entropy values)
- `event.isTrusted = true` for dispatched events
- `navigator.webdriver = undefined`
- **3,520 tracker domains blocked**

Current binary at `~/.local/bin/obscura` is the **stealth-enabled** build (compiled with `--features stealth`). Full anti-fingerprinting, tracker blocking (3,520 domains), and `navigator.webdriver = undefined`.

## CDP API

| Domain | Methods |
|--------|---------|
| Target | createTarget, closeTarget, attachToTarget, createBrowserContext, disposeBrowserContext |
| Page | navigate, getFrameTree, addScriptToEvaluateOnNewDocument, setDeviceMetricsOverride, setTouchEmulationEnabled |
| Runtime | evaluate, runIfWaitingForDebugger, releaseObject, releaseObjectGroup |
| Network | enable, disable, setCacheDisabled, setUserAgentOverride, getCookies, deleteCookies, setCookies |
| DOM | getDocument, querySelector, querySelectorAll, getOuterHTML, setOuterHTML, requestChildNodeSearch, highlightRect |
| Input | dispatchKeyEvent, dispatchMouseEvent, dispatchTouchEvent, insertText, setFileInputFiles |
| Storage | getStorageKeyForFrame |
| Emulation | setDeviceMetricsOverride, setTouchEmulationEnabled |

## Why Use

- **30 MB** memory vs 200+ MB Chrome
- **85 ms** page load vs ~500 ms
- No Chrome/Node.js dependency
- Drop-in CDP replacement for Puppeteer/Playwright
- Anti-detection built into stealth mode

## URL

https://github.com/h4ckf0r0day/obscura
