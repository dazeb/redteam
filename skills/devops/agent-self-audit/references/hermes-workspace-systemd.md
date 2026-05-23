# Hermes Workspace — Systemd Service Setup

Setting up `hermes-workspace` (React/Vite + Node.js backend) as a systemd user service that starts on boot, alongside `hermes-dashboard` and `hermes-gateway`.

## Prerequisites

- workspace cloned at `~/hermes-workspace`
- `pnpm build` has run successfully
- `dist/client/index.html` exists (built frontend)

## 1. Fix `server-entry.js` Duplicate Declaration

A known bug: `cookieSecureOverride` is declared twice in `server-entry.js` (lines 57-70 and 72-85 are identical). Remove the second block:

```python
with open('server-entry.js') as f:
    lines = f.readlines()
del lines[71:85]  # remove duplicate block (0-indexed)
with open('server-entry.js', 'w') as f:
    f.writelines(lines)
```

Verify: `node --check server-entry.js` should pass.

## 2. Configure .env

Set required env vars in `~/hermes-workspace/.env`:

```bash
PORT=3002                          # avoid conflict with stale 3001
HERMES_API_URL=http://127.0.0.1:8650
HERMES_API_TOKEN=<same-as-API_SERVER_KEY>
```

The API server uses `Authorization: Bearer <token>`. Set `HERMES_API_TOKEN` to the same value as `API_SERVER_KEY` in `~/.hermes/config.yaml` (generated with `openssl rand -hex 32`).

## 3. Create Startup Script

`~/scripts/start-hermes-workspace.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source nvm for Node.js PATH (systemd doesn't inherit user shell)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

ROOT="$(cd "$(dirname "$0")/../hermes-workspace" && pwd)"
cd "$ROOT"

# Source workspace .env so Node picks up HERMES_API_TOKEN and other config
if [ -f "$ROOT/.env" ]; then
  set -a
  source "$ROOT/.env"
  set +a
fi

export NODE_ENV=production
export NODE_OPTIONS="--max-old-space-size=2048"
echo "[hermes-workspace] Starting on port ${PORT:-3002}..."
exec node server-entry.js
```

Make executable: `chmod +x ~/scripts/start-hermes-workspace.sh`

## 4. Create systemd Service

`~/.config/systemd/user/hermes-workspace.service`:

```ini
[Unit]
Description=Hermes Workspace
After=network.target hermes-dashboard.service

[Service]
Type=simple
WorkingDirectory=/home/dazeb/hermes-workspace
ExecStart=/home/dazeb/scripts/start-hermes-workspace.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

## 5. Enable and Start

```bash
systemctl --user daemon-reload
systemctl --user enable hermes-workspace.service
systemctl --user start hermes-workspace.service
```

## 6. Verify

```bash
curl -s http://127.0.0.1:3002/api/connection-status
# Should return: {"status":"enhanced","health":true,"chatReady":true,...}
```

## Pitfalls

1. **port conflict with stale process.** If `PORT=3001` was set in `.env` and an old instance is still running, the service crashes with `EADDRINUSE`. Kill the old process and use port 3002.
2. **system vs nvm npm.** systemd doesn't inherit shell env. Must source nvm in the start script or node/pnpm won't be found (exit code 127).
3. **Bearerauth mismatch.** The API server uses Bearer tokens, not `X-API-Key`. The workspace's `HERMES_API_TOKEN` env var must be set (it reads `process.env.HERMES_API_TOKEN || process.env.CLAUDE_API_TOKEN`).
4. **`hermes gateway restart` crash loop.** When other Hermes CLI sessions are active, `--replace` exits with status 75. Use `systemctl --user stop/start` instead.
