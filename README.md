# redteam-profile

Opinionated Hermes scenario bundle for the ai-supply-chain-lab red team workflow.

## What this distribution includes

- SOUL.md
- config.yaml
- mcp.json
- skills/
- cron/
- distribution.yaml

## What it does not include

- .env
- auth.json
- memories/
- sessions/
- state.db*
- logs/
- workspace/
- plans/
- *_cache/
- local/

These remain on the installer’s machine.

## Install

```bash
hermes profile install github.com/dazeb/redteam-dist --alias
```

## Update

```bash
hermes profile update redteam-dist
```

## Notes

- cron jobs are shipped in the repo but not auto-enabled
- config.yaml is preserved on update unless --force-config is used
- the installed profile is not a git checkout
- use local/ for personal overrides that should never be distributed
