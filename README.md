# redteam-profile

Opinionated Hermes scenario bundle for the ai-supply-chain-lab red team workflow.

Includes everything for the hermes redteam profile. Supply Chain Scenario setup https://github.com/dazeb/ai-supply-chain-lab

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

```bash
# Switch to redteam profile
hermes --profile redteam

# Or set as default for a session
hermes profile use redteam
```
Every profile automatically gets a command alias at `~/.local/bin/<name>:`

```bash
hermes profile use redteam
hermes chat                   # now targets redteam
hermes tools                  # configures redteam's tools
hermes profile use default    # switch back
```

## Skills

```bash
redteam                    # chat with the coder agent
redteam setup                   # configure coder's settings
redteam gateway start           # start coder's gateway
redteam doctor                  # check coder's health
redteam skills list             # list coder's skills
redteam config set model.default deepseek/deepseek-v4-pro  # set default model
```

## Update

```bash
hermes profile update redteam
```

## Notes

- cron jobs are shipped in the repo but not auto-enabled
- config.yaml is preserved on update unless --force-config is used
- the installed profile is not a git checkout
- use local/ for personal overrides that should never be distributed
