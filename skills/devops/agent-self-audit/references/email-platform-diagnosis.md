# Email Platform Diagnosis — IMAP Authentication Failures

Diagnosing Hermes gateway email platform `[AUTHENTICATIONFAILED]` errors.

## Error Signature

```
ERROR gateway.platforms.email: [Email] IMAP connection failed: b'[AUTHENTICATIONFAILED] Authentication failed.'
```

This means Dovecot (or the IMAP server) is reachable but rejecting the password. Not a firewall/DNS/TLS issue.

## Diagnosis Steps (in order)

### 1. Check Gateway Health

```bash
curl -s http://127.0.0.1:8650/health | python3 -m json.tool
# Or the v1 endpoint:
curl -s http://127.0.0.1:8650/v1/health
```

If the gateway is running but the email platform has errors, it won't show in the top-level health (which only says `"status": "ok"`). The actual email platform status must be checked in the logs.

### 2. Check Gateway Logs

```bash
journalctl --user -u hermes-gateway --no-pager | grep -i "email\|imap\|auth" | tail -20
```

Look for the retry interval — the gateway retries on a timer (seen at ~5 minute intervals in practice).

### 3. Test IMAP Connectivity (TLS)

```bash
# Test TCP + TLS handshake
echo | openssl s_client -connect mail.example.com:993 2>&1 | head -10

# Expected output shows:
#   * OK [CAPABILITY ...] Dovecot ready.
#   Certificate chain + valid dates
```

If this works, the server is reachable and TLS is valid. Problem is credentials, not connectivity.

### 4. Test IMAP Login Directly (Python)

Use Python's `imaplib` for a clean test — avoids shell escaping issues with openssl:

```python
import imaplib, ssl
ctx = ssl.create_default_context()
m = imaplib.IMAP4_SSL('mail.example.com', 993, ssl_context=ctx)
m.login('user@example.com', 'password')
print('LOGIN OK')
m.logout()
```

If this fails with `[AUTHENTICATIONFAILED]`, the password is definitely wrong. No other interpretation.

### 5. Check Config Location

The gateway reads email config from environment variables:

| Variable | Example |
|----------|---------|
| `EMAIL_ADDRESS` | `denny@dennysentinel.com` |
| `EMAIL_PASSWORD` | `************` |
| `EMAIL_IMAP_HOST` | `mail.v0cl.one` |
| `EMAIL_SMTP_HOST` | `mail.v0cl.one` |

These are typically in `/home/dazeb/.hermes/.env`.

## Common Causes

| Cause | What to look for |
|-------|-----------------|
| Password changed | Worked before, stopped suddenly |
| 2FA/app password required | Account has 2FA enabled; IMAP needs app-specific password |
| Account locked | Check webmail access |
| Auth mechanism mismatch | Dovecot may require LOGIN vs PLAIN; `imaplib` uses LOGIN by default |
| Plaintext password rejected | Some servers reject non-TLS auth; we use port 993 (TLS) |

## Resolution Options

1. **Update password**: Edit `.env` with the correct password, restart gateway
2. **Generate app password**: If 2FA is on, create an app-specific password for IMAP
3. **Disable email platform**: In `config.yaml`, remove or comment out the email platform section, then restart gateway

## Gateway Restart

```bash
systemctl --user stop hermes-gateway
systemctl --user start hermes-gateway
# Do NOT use systemctl restart — it can trigger infinite restarts
```
