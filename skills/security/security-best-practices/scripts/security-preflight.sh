#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/security-preflight.sh [--repo <path>] [--skip-history]

Runs a first-go-live security preflight for x3s-style deployments.

Checks:
- deploy/live-mode preflight if available
- production env validation if available
- tracked-file secret heuristics with redacted output
- git history heuristics for likely secret-bearing commits
- container/runtime hardening flags in compose and infra files
- suspicious regex / ReDoS heuristics in source files

This script is intentionally defensive. It reports findings without printing
secret values.
EOF
}

REPO=""
SKIP_HISTORY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --skip-history)
      SKIP_HISTORY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

find_repo_root() {
  local start="$1"
  local current
  current="$(cd "$start" && pwd)"
  while [[ "$current" != "/" ]]; do
    if [[ -d "$current/.git" ]]; then
      echo "$current"
      return 0
    fi
    current="$(dirname "$current")"
  done
  return 1
}

if [[ -z "$REPO" ]]; then
  if ! REPO="$(find_repo_root "$PWD")"; then
    echo "Could not find repo root. Use --repo <path>." >&2
    exit 1
  fi
fi

REPO="$(cd "$REPO" && pwd)"
cd "$REPO"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "rg is required" >&2
  exit 1
fi

ERRORS=0
WARNINGS=0

GIT_EXCLUDES=(
  ':(exclude)docker/*/static/vendor/*'
  ':(exclude)docker/*/ui/playwright.config.js'
  ':(exclude)convex/_generated/*'
  ':(exclude)**/*.min.js'
)

RG_EXCLUDES=(
  --glob '!docker/*/static/vendor/*'
  --glob '!convex/_generated/*'
  --glob '!**/*.min.js'
)

ok() {
  echo "OK: $1"
}

warn() {
  echo "WARN: $1"
  WARNINGS=$((WARNINGS + 1))
}

error() {
  echo "ERROR: $1"
  ERRORS=$((ERRORS + 1))
}

run_optional_script() {
  local rel="$1"
  shift
  if [[ -x "$REPO/$rel" ]]; then
    if "$REPO/$rel" "$@"; then
      ok "$rel $*"
    else
      error "$rel $* failed"
    fi
  else
    warn "$rel not found or not executable; skipped"
  fi
}

print_section() {
  echo
  echo "== $1 =="
}

tracked_files() {
  git ls-files
}

print_redacted_matches() {
  local label="$1"
  local pattern="$2"
  if git grep -nI -P "$pattern" -- . "${GIT_EXCLUDES[@]}" >/tmp/security_preflight_hits.$$ 2>/dev/null; then
    warn "$label found in tracked files"
    cut -d: -f1 /tmp/security_preflight_hits.$$ | sort -u | while IFS= read -r file; do
      rg -n --pcre2 "$pattern" "$file" -r '[REDACTED]' || true
    done
  else
    ok "$label not detected in tracked files"
  fi
  rm -f /tmp/security_preflight_hits.$$
}

print_section "1) Existing repo gates"
run_optional_script "scripts/deploy-preflight.sh" --strict-live
run_optional_script "scripts/validate-env.sh" --prod

print_section "2) Tracked-file secret heuristics"
print_redacted_matches "Stripe-style secret keys" '(sk_(live|test)_[A-Za-z0-9]{8,})'
print_redacted_matches "GitHub personal access tokens" '(gh[pousr]_[A-Za-z0-9_]{20,})'
print_redacted_matches "AWS access key ids" '(AKIA[0-9A-Z]{16})'
print_redacted_matches "Slack tokens" '(xox[baprs]-[A-Za-z0-9-]{10,})'
print_redacted_matches "Google API key style strings" '(AIza[0-9A-Za-z\\-_]{20,})'
print_redacted_matches "Likely private key blocks" 'BEGIN (RSA|EC|OPENSSH|DSA|PGP) PRIVATE KEY'
print_redacted_matches "Suspicious secret variable assignments" '((SECRET|TOKEN|API[_-]?KEY|PASSWORD|PRIVATE[_-]?KEY|ENCRYPTION[_-]?KEY)\s*[:=]\s*["'\'']?[A-Za-z0-9_./+=:-]{12,})'

print_section "3) Git history heuristics"
if [[ "$SKIP_HISTORY" == "true" ]]; then
  warn "git history scan skipped"
else
  HISTORY_PATTERN='sk_(live|test)_|gh[pousr]_|AKIA[0-9A-Z]{16}|xox[baprs]-|AIza|BEGIN (RSA|EC|OPENSSH|DSA|PGP) PRIVATE KEY|SECRET|TOKEN|API[_-]?KEY|PASSWORD|PRIVATE[_-]?KEY'
  if git log --all --format='%H %s' -G "$HISTORY_PATTERN" -- . >/tmp/security_preflight_history.$$ 2>/dev/null; then
    if [[ -s /tmp/security_preflight_history.$$ ]]; then
      warn "possible secret-related history entries found"
      sed -n '1,40p' /tmp/security_preflight_history.$$
      echo "INFO: rotate first, then clean history with git filter-repo if needed"
    else
      ok "no obvious secret-related history entries matched heuristics"
    fi
  else
    warn "git history heuristic scan failed"
  fi
  rm -f /tmp/security_preflight_history.$$
fi

print_section "4) Container and runtime hardening heuristics"
container_pattern='privileged:\s*true|network_mode:\s*host|pid:\s*host|ipc:\s*host|/var/run/docker\.sock|cap_add:|seccomp=unconfined|apparmor=unconfined|user:\s*root'
if rg -n --pcre2 "$container_pattern" "${RG_EXCLUDES[@]}" docker-compose* compose* "**/*.yml" "**/*.yaml" "**/Dockerfile*" >/tmp/security_preflight_container.$$ 2>/dev/null; then
  warn "container-risk indicators found"
  sed -n '1,80p' /tmp/security_preflight_container.$$
else
  ok "no obvious container-risk indicators matched"
fi
rm -f /tmp/security_preflight_container.$$

print_section "5) Regex and ReDoS heuristics"
regex_pattern='new RegExp\(|\(([^)\n]{0,80}[+*][^)\n]{0,80})\)[+*]|(\[[^]\n]{1,40}\]|\.[*+]){2,}'
if rg -n --pcre2 "$regex_pattern" "${RG_EXCLUDES[@]}" --glob '*.{js,jsx,ts,tsx,py,go,java,rb,php}' >/tmp/security_preflight_regex.$$ 2>/dev/null; then
  warn "regex patterns worth manual ReDoS review found"
  sed -n '1,80p' /tmp/security_preflight_regex.$$
else
  ok "no suspicious regex heuristics matched"
fi
rm -f /tmp/security_preflight_regex.$$

print_section "6) Manual go-live confirmations"
cat <<'EOF'
MANUAL:
- Confirm public hostnames, websocket paths, and proxy routes are intentionally exposed.
- Confirm pairing/auth model for each runtime.
- Confirm rollback steps are written and operator-usable.
- Confirm monitoring/log access exists for first deploy window.
- Confirm any previously leaked development secrets are rotated.
EOF

print_section "Summary"
echo "Repo:      $REPO"
echo "Errors:    $ERRORS"
echo "Warnings:  $WARNINGS"

if [[ $ERRORS -gt 0 ]]; then
  exit 1
fi

exit 0
