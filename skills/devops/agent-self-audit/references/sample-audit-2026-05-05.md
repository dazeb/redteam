# Annotated Self-Audit — 2026-05-05

Real findings from a systematic Hermes Agent health check. Each finding maps to a checklist step.

## Findings (Severity-Ordered)

### 🔴 CRITICAL: API Server Unauthenticated

**Check:** `grep -A5 "api_server:" ~/.hermes/config.yaml`

```yaml
api_server:
    extra:
      port: 8650
      key: ''        # ← empty!
      host: 127.0.0.1
```

**Symptom:** `gateway.log` shows:
```
WARNING gateway.platforms.api_server: [Api_Server] ⚠️ No API key configured
```

**Fix:**
```bash
openssl rand -hex 32  # generates key
# Set in config.yaml → platforms.api_server.key
# Add API_SERVER_KEY=<key> to ~/.hermes/.env
```

**Note:** The API server uses `Authorization: Bearer <key>`, not `X-API-Key`. Any downstream
clients (workspace, custom apps) must send Bearer auth. `/health` returns 200 unauthenticated,
but `/v1/models` returns 401.

---

### 🟡 HIGH: planforge Plugin — Silent Import Failure

**Check:** `grep "Failed to load plugin" ~/.hermes/logs/errors.log`

```
WARNING hermes_cli.plugins: Failed to load plugin 'planforge': No module named 'planforge'
```

**Root cause 1:** Plugin's `__init__.py` used absolute import `from planforge.__init__ import register`
but the plugin loader doesn't add the plugin root to `sys.path`. The `planforge/` subdirectory
is a sibling of `__init__.py`, not on the module search path.

**Fix 1:** Use relative import in the outer `__init__.py`:
```python
from .planforge.__init__ import register
```

**Root cause 2:** After fixing the import, a second error:
```
'PluginContext' object has no attribute 'log'
```

The planforge `register()` function calls `ctx.log.info(...)`. PluginContext does not expose `.log`.

**Fix 2:** Guard all `ctx.log` calls:
```python
try:
    ctx.log.info(f"PlanForge v{__version__} registered")
except AttributeError:
    print(f"[PlanForge] v{__version__} registered")
```

Apply the same guard to hook functions (`_hook_pre_tool_call` → `ctx.log.warning`).

**Verification:** Journal shows `[PlanForge] v0.1.0 registered — spec-driven planning ready` on gateway start.

---

### 🟡 HIGH: Tool Registration Shadowing — `web_extract`

**Check:** `grep "would shadow" ~/.hermes/logs/errors.log`

```
ERROR tools.registry: Tool registration REJECTED: 'web_extract' (toolset 'web')
would shadow existing tool from toolset 'evey_research'. Deregister the existing tool first.
```

Two providers register the same tool name:
- Built-in `web` toolset: `web_extract` (Firecrawl, batch URLs, LLM processing, secret detection)
- `evey-research` plugin: `web_extract` (Crawl4AI, single URL, simple extraction)

The built-in version is more capable but gets rejected because plugins load before built-in tools.

**Fix:** Remove the duplicate `ctx.register_tool(name="web_extract", ...)` from
`~/.hermes/plugins/evey-research/__init__.py`. Keep only `web_research` and `save_finding`.

---

### 🟡 HIGH: Cron Jobs in HTTP 429 Loop

**Check:** `hermes cron list`

```
frodo-memory-compressor   error: RuntimeError: HTTP 429: The usage limit has been reached
nvidia-memory-compressor  error: RuntimeError: HTTP 429: The usage limit has been reached
```

Both jobs run every 3 hours using the default openai-codex/gpt-5.5 model. That provider is rate-limited.
The jobs only run a local Python script via `terminal` tool — no LLM reasoning needed.

**Fix:** Convert to `--no-agent` mode:
```bash
hermes cron edit 7e4106e94c80 --script frodo-memory-compressor.py --no-agent
hermes cron edit ddf5bf88f51c --script nvidia-memory-compressor.py --no-agent
```

Zero-token operation — the script runs directly, stdout delivered as-is. No more 429s.

---

### 🟡 MEDIUM: Gateway Crash Loop After Restart

**Symptom:** After `hermes gateway restart`, systemd shows:
```
Active: activating (auto-restart) (Result: exit-code) ... code=exited, status=75
```

Exit 75 = EX_TEMPFAIL. The `--replace` flag detects active Hermes CLI/dashboard processes
and gracefully exits. During a systemd restart, this creates a crash loop.

**Fix:** Use stop/start instead of restart:
```bash
systemctl --user stop hermes-gateway && systemctl --user start hermes-gateway
```

---

### 🟢 OPPORTUNITY: Useful Plugins Disabled

Five high-value plugins were available but disabled. Enabled in this audit:

| Plugin | Value |
|--------|-------|
| `disk-cleanup` | Auto-cleans ephemeral session files |
| `evey-cache` | 24h delegation result caching (saves tokens) |
| `evey-cost-guard` | Budget enforcement + Langfuse analytics |
| `evey-watchdog` | Self-monitoring with ntfy alerts |
| `evey-sandbox` | Docker-sandboxed code execution |

Enable: `hermes plugins enable <disk-cleanup|evey-cache|evey-cost-guard|evey-watchdog|evey-sandbox>`

---

## What Passed Clean

- Config v23, all required keys present
- All providers authenticated (DeepSeek, OpenRouter, NVIDIA, HF)
- MCP (Leonardo) connected and enabled
- Gateway: Telegram + Discord operational
- Memory: MEMORY.md, USER.md, Mem0 all healthy
- 331 sessions in state.db (healthy count)
- Git repo synced, no dirty working tree
- Systemd linger enabled (gateway survives logout)
