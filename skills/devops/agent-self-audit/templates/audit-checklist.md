# Hermes Agent Self-Audit Checklist

**Date:** ___________ **Auditor:** ___________ **Version:** ___________

## Phase 1: Configuration & Version
- [ ] `hermes --version` → no "commits behind" warning
- [ ] `hermes config check` → all required keys present
- [ ] `hermes doctor` → no critical warnings

## Phase 2: Error Logs
- [ ] `tail -100 ~/.hermes/logs/errors.log` — reviewed
- [ ] No `Tool registration REJECTED` errors
- [ ] No `Failed to load plugin` errors
- [ ] No `HTTP 429` on cron jobs
- [ ] No unhandled exceptions

## Phase 3: Plugins
- [ ] `hermes plugins list` → all enabled plugins load cleanly
- [ ] Cross-referenced with errors.log → no silent failures

## Phase 4: Cron Jobs
- [ ] `hermes cron list` → all active jobs show `last run: ok`
- [ ] No `error` status on any job

## Phase 5: Gateway
- [ ] `systemctl --user status hermes-gateway` → Active (running)
- [ ] No auto-restart loop
- [ ] No API key warnings in gateway log

## Phase 6: Security
- [ ] `API_SERVER_KEY` is set (not empty)
- [ ] API server bound to 127.0.0.1 (unless LAN deployment)

## Phase 7: Services
- [ ] `hermes-gateway` → running + enabled
- [ ] `hermes-dashboard` → running + enabled
- [ ] `hermes-workspace` → running + enabled (if applicable)

## Phase 8: Tools & Features
- [ ] `hermes tools list` → expected toolsets enabled
- [ ] MCP servers connected (if configured)
- [ ] `hermes sessions stats` → reasonable session count (<500 unpruned)

## Phase 9: Memory & Skills
- [ ] MEMORY.md under size limit (check ~/.hermes/memories/)
- [ ] Skills directory no stale/empty entries
- [ ] Mem0 search returns results

## Findings

| # | Severity | Description | Fixed? |
|---|----------|-------------|--------|
| 1 |          |             |        |
| 2 |          |             |        |
| 3 |          |             |        |

## Actions Taken

____________________________________________________
____________________________________________________
____________________________________________________

## Follow-up Items

____________________________________________________
____________________________________________________
