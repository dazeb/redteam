---
name: agent-self-audit
description: Systematic health audit of a Hermes Agent installation — error logs, plugins, cron jobs, config security, gateway status, and feature integrity. Run periodically or after heavy usage to detect decay.
version: 1.0.0
---

# Agent Self-Audit

At least quarterly (or after heavy multi-session usage), run a structured self-audit to catch:
- Silent plugin load failures
- Tool registration conflicts
- Cron jobs stuck in error loops
- Unauthenticated services (API server)
- Gateway auto-restart loops
- Provider rate-limit exhaustion on scheduled jobs

## Triggers

- User asks "check yourself", "audit your internals", "self-diagnose", "is everything working"
- Gateway shows repeated auto-restart cycles
- Cron jobs report persistent failures
- Features stop working without obvious cause

## Audit Checklist (Run in Order)

### 1. Version & Config Health

```bash
hermes --version                    # check for update: "X commits behind"
hermes config check                 # config version, missing keys
hermes doctor                       # full environment health
```

**Watch for:**
- Config version mismatch
- Missing API keys for critical providers
- No `API_SERVER_KEY` set → unauthenticated API server

### 2. Error Log Review

```bash
tail -100 ~/.hermes/logs/errors.log
```

**High-signal patterns to grep for:**
```
FAILED|ERROR|REJECTED|HTTP 429|No module named|would shadow|unhandled exception|stale-code
```

Every non-429 error is actionable. Flag:
- `Tool registration REJECTED` → two toolsets conflict on same name
- `Failed to load plugin 'X': No module named` → broken plugin import
- `Stale-code self-check` → gateway needs restart (or it already did)
- `reasoning_content` API errors → provider thinking-mode mismatch
- `HTTP 429` on cron jobs → rate-limited provider, switch to no-agent mode

### 3. Plugin Health

```bash
hermes plugins list | grep "enabled"
```

Cross-reference enabled plugins with error log. Any plugin showing "enabled" but also "Failed to load" in the log is silently broken.

**Common failure modes:**
- `No module named 'X'` → absolute import fails; fix with relative import or path injection
- `'PluginContext' object has no attribute 'log'` → plugin uses `ctx.log` which doesn't exist; guard with try/except
- Plugin shows enabled but doesn't register tools → import error swallowed by loader

### 4. Tool Conflict Detection

```bash
grep "would shadow" ~/.hermes/logs/errors.log
```

Two providers registering the same tool name. One silently loses. Resolve by removing the duplicate registration from the less-capable provider.

### 5. Cron Job Health

```bash
hermes cron list
```

**Red flags:**
- `Last run: error` — repeated failures
- `error: RuntimeError: HTTP 429` — provider rate-limited
- Jobs running frequently but producing errors every cycle

**Fix for rate-limited cron jobs:** Convert to `--no-agent` mode if the job just runs a script:

```bash
hermes cron edit <job_id> --script <script.py> --no-agent
```

This eliminates the LLM call overhead entirely — the script runs directly with zero tokens.

### 6. Gateway Status

```bash
systemctl --user status hermes-gateway --no-pager | head -5
```

**Red flags:**
- `Activating (auto-restart)` → crash loop, check journal
- Exit code 75 (EX_TEMPFAIL) → gateway sees other Hermes processes and shuts down
- Gateway `--replace` flag doesn't play well with active CLI sessions — use `systemctl --user stop/start` instead of `hermes gateway restart`

```bash
journalctl --user -u hermes-gateway -n 20 --no-pager
```

### 7. API Server Security

```bash
grep -A 5 "api_server:" ~/.hermes/config.yaml
```

If `key: ''` is empty, the API server accepts unauthenticated requests. Generate and set a key:

```bash
openssl rand -hex 32  # generates the key
# Set in config.yaml: platforms.api_server.key
# Also add API_SERVER_KEY=<key> to ~/.hermes/.env
```

### 8. Verify Services on Boot

```bash
systemctl --user list-units --type=service --state=running | grep hermes
```

All expected services (gateway, dashboard, workspace) should be running and `enabled`.

### 9. Feature Integrity Smoke Test

```bash
hermes tools list | grep "✓ enabled"
```

Verify all expected toolsets are active. Check anything marked `✗ disabled` — was it intentionally disabled?

### 10. Disk Space Check

```bash
df -h / | tail -1
```

If usage is at 99-100%, even tiny operations (49KB file copies) will fail. Quick-win cleaners:

```bash
du -sh ~/.cache/pip ~/.cache/pnpm ~/.hermes/state-snapshots 2>/dev/null
```

- **pip cache:** `rm -rf ~/.cache/pip` — routinely 4-5G of stale wheels
- **pnpm cache:** `rm -rf ~/.cache/pnpm` — 100-200M typical
- **State snapshots:** `ls -dt ~/.hermes/state-snapshots/*/ | tail -n +4 | xargs rm -rf` — keep 3 most recent

The `disk-cleanup` plugin (if enabled) handles ephemeral session files automatically, but these caches are outside its scope.

### 12. Accidental Home-Directory Git Repo

A `git init` accidentally run in `/home/dazeb` (or any large directory) will silently track every file — no remotes, no `.gitignore`. Over weeks/months this can balloon to 600GB+ with hundreds of thousands of loose objects and pack files. Detected by `du -sh ~/.git` showing hundreds of GB.

**Diagnose:**
```bash
git -C /home/dazeb rev-parse --is-inside-work-tree 2>&1
# If true and no remote or .gitignore → accidental
git -C /home/dazeb remote -v 2>&1
# Empty = no remotes = no real repo
```

**Clean:**
```bash
rm -rf ~/.git
```

Expect 30-60s for large repos. Pack files delete last. Check progress with `df -h /`.

**Prevention:** After removing the repo, create a `~/.gitignore` so it can't happen again. The `home-directory-reorganization` skill includes a template — see Step 7 (Create `.gitignore` Safety Net) for the exact file.

### 11. State Database Health & Maintenance

```bash
ls -lh ~/.hermes/state.db*
# Check sizes: state.db, state.db-wal (WAL), state.db-shm (shared memory)
```

**Red flags:**
- `state.db > 100MB` with `auto_prune: false` — sessions are accumulating with no automatic cleanup
- `state.db-wal > 50MB` — write-ahead log has grown large; indicates no recent checkpoint
- Session count > 500 — likely bloated, consider pruning

**Check config:**
```bash
grep -A3 'sessions:' ~/.hermes/config.yaml | grep -E 'auto_prune|retention'
```

If `auto_prune: false`, old sessions never get cleaned. Enable:
```yaml
sessions:
  auto_prune: true
  retention_days: 90
  vacuum_after_prune: true
```

**Immediate space reclamation:**
```bash
# Prune old sessions (dry first, then execute)
hermes sessions prune --older-than 90 -y
```

WAL files don't shrink from CLI operations alone. Force a checkpoint:
```python
python3 -c "
import sqlite3, os
db = os.path.expanduser('~/.hermes/state.db')
conn = sqlite3.connect(db)
conn.execute('PRAGMA wal_checkpoint(TRUNCATE)')
conn.execute('VACUUM')
conn.close()
print(f'state.db: {os.path.getsize(db)/1024/1024:.0f} MB')
"
```

**PITFALL:** The WAL regrows immediately if the gateway is running (it writes continuously). The checkpoint + VACUUM is a one-time space recovery, not a permanent fix. The permanent fix is `auto_prune: true` — it keeps the trend downward by removing old sessions before they accumulate.

## Post-Audit Actions

1. Fix CRITICAL items immediately (unauthenticated services, crash loops)
2. Fix HIGH items same session (silent plugin failures, tool conflicts, stuck crons)
3. Enable opportunistic items (useful disabled plugins)
4. Gateway restart: `systemctl --user stop hermes-gateway && systemctl --user start hermes-gateway` (prefer over `hermes gateway restart` when CLI sessions are active)

## Supporting Files

- **references/sample-audit-2026-05-05.md** — Annotated sample audit run showing real findings: planforge import failure, web_extract conflict, unauthenticated API server, cron HTTP 429, gateway crash loop. Use as a reference for severity classification.
- **references/hermes-workspace-systemd.md** — Full recipe for setting up hermes-workspace as a systemd service: nvm sourcing, .env loading, server-entry.js bug fix, Bearer auth token matching, and port conflict resolution.
- **references/email-platform-diagnosis.md** — Diagnosing Hermes gateway email platform IMAP authentication failures. Step-by-step: check logs, test IMAP connectivity with openssl, test login with Python imaplib, interpret Dovecot errors, resolution options.
- **templates/audit-checklist.md** — Printable checklist version with checkbox columns for scheduled audits.
