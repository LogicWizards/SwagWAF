# SwagWAF — BIG-IP v17.x QA Validation Guide

```
# --------------------------------------------------------------------------
# NOTES:    testing-v17.1.md
# --------------------------------------------------------------------------
# ABSTRACT: QA testing guide for SwagWAF v0.3.8 on BIG-IP v17.x, including
#     deployment, trusted-source policy, logs, and ISA evidence collection.
# CREATED:  260708 BY: Claude(Sonnet4.6)::Copilot
# UPDATED:  260730 BY: JN
# VERSION:  0.3.8
# ARCHITECT: JN
# TECHLEAD: JN
# STAGE:    ACTIVE
# --------------------------------------------------------------------------
```

---

## v17.x Behavioral Differences (vs v15/v16)

| Behavior | v15/v16 | v17.x | SwagWAF fix |
|---|---|---|---|
| `class match ... matches_regex` | Supported | **Removed** — parse error at save time | Switched to `contains` |
| Literal DG names in `class` ops | Validated at runtime | **Validated at VIP-assignment time** — blocks apply if DG absent | DG name stored in `$static::dg_name` variable; bypasses static check |
| `class match -element` | Returns `{name value}` list | Same | Switched to `-name` (returns key string only) |

---

## Pre-Flight: Apply the iRule to a VIP

SwagWAF v0.3.8 uses variable DG references to bypass v17.x link-time validation. No
data group needs to exist before the iRule is applied. The jailbreak-pattern and
trusted-source readiness checks fail independently at `RULE_INIT`.

```bash
# Apply via tmsh (replace partition/name as needed)
tmsh modify ltm virtual /Common/my-vip rules { /Common/ADMIN-SwagWAF }
tmsh save sys config
```

Expected in `/var/log/ltm` (no `01070151` errors):
```
SwagWAF: dg_swagwaf_jailbreak_patterns not deployed — static fallback active (13 patterns)
```

If you see `01070151` errors, the running iRule may use a literal DG reference. Verify
that both optional names are assigned to variables:
```bash
tmsh list ltm rule /Common/ADMIN-SwagWAF | grep -E 'dg_name|trusted_sources_dg'
```

---

## Automated Smoke Tests

Run the assertion suite from any host with network access to the VIP:

```bash
export VIP="https://claimqa.erp.fordham.edu"   # full URL including https://
bash examples/curl/test-swagwaf.sh
```

Expected output (static fallback mode, no DG deployed):
```
SwagWAF smoke tests — https://claimqa.erp.fordham.edu
==========================================

[ 1 ] Clean request baseline
  PASS  Clean request not blocked (HTTP 200)

[ 2 ] Injection detection — HIGH tier (expect 403 DG or 400 fallback)
  PASS  HIGH injection rejected (HTTP 400)

[ 3 ] Rate limiting — 110 requests at concurrency 25
  PASS  Rate limit triggered (HTTP 429)

[ 4 ] Security headers
  PASS  Strict-Transport-Security present
  PASS  Cache-Control present
  PASS  X-Content-Type-Options present
  PASS  Server removed
  PASS  X-Powered-By removed

==========================================
  Results: 8 passed, 0 failed
==========================================
```

---

## Manual Log Validation (ISA Evidence)

After each test, grep `/var/log/ltm` on the BIG-IP for structured security events:

```bash
# All SwagWAF security events
grep "SWAGWAF|" /var/log/ltm | tail -50

# Injection attempts only
grep "SWAGWAF|INJECTION_ATTEMPT" /var/log/ltm

# Blocks (rate + injection threshold)
grep "SWAGWAF|BLOCKED" /var/log/ltm

# Rate limiting
grep "SWAGWAF|RATE_LIMITED" /var/log/ltm
```

### Expected log format (v0.3.6+)

```
Jul  9 14:23:11 bigip01 info tmm[12345]: Rule /Common/ADMIN-SwagWAF <HTTP_REQUEST_DATA>: \
  SWAGWAF|INJECTION_ATTEMPT|src=10.10.1.5|xff=10.10.1.5|client_xff=(none)|dst=150.108.36.30|\
  vip=/Common/S2DACMIMGTQA-F5_ERP_FORDHAM_EDU_443_FE_VIP|method=POST|\
  uri=/v1/chat/completions|phrase="ignore previous instructions"|threat=HIGH
```

### Sumo Logic queries (log aggregator: `qa/security/lb/f5`)

```
# All SwagWAF events
_sourceCategory=qa/security/lb/f5 "SWAGWAF|"

# Security events only (no TRACE)
_sourceCategory=qa/security/lb/f5 ("SWAGWAF|INJECTION_ATTEMPT" OR "SWAGWAF|BLOCKED" OR "SWAGWAF|RATE_LIMITED" OR "SWAGWAF|LOW_RISK" OR "SWAGWAF|TLS_REJECTED")

# With field extraction
_sourceCategory=qa/security/lb/f5 "SWAGWAF|"
| parse "src=*|" as src
| parse "xff=*|" as xff
| parse "client_xff=*|" as client_xff
| parse "dst=*|" as dst
| parse "vip=*|" as vip
| parse "phrase=*|" as phrase nodrop
| parse "threat=*|" as threat nodrop
| fields _messageTime, src, client_xff, dst, vip, phrase, threat

# XFF spoofing detection
_sourceCategory=qa/security/lb/f5 "SWAGWAF|"
| parse "src=*|" as src
| parse "client_xff=*|" as client_xff
| where client_xff != "(none)" and client_xff != src
| fields _messageTime, src, client_xff
```

| Field | Value | Notes |
|---|---|---|
| `src=` | Client IP as seen by BIG-IP | Same as `xff=` for direct connections |
| `xff=` | `IP::remote_addr` | F5-sanitized — cannot be spoofed |
| `vip=` | Virtual server path | Confirms which VIP fired |
| `phrase=` | Matched literal substring | Key from DG or static list |
| `threat=` | HIGH / MEDIUM / LOW | Tier from DG; always HIGH in static fallback |
| `dg=static_fallback` | Present when DG not deployed | Confirms fallback path |

### Trusted-source evidence

With `/Common/dg_swagwaf_trusted_sources` deployed, send traffic from a matching host
or CIDR and confirm the canonical record and metadata are visible:

```bash
grep 'SWAGWAF|TRUSTED_SOURCE' /var/log/ltm | tail
```

Then repeat the burst from an untrusted source and confirm `RATE_LIMITED` or `BLOCKED`.
A trusted source bypasses only rate limiting; injection tests must still be rejected.

---

## DG Activation Validation (Optional — when DG is available)

```bash
# 1. Deploy the data group
tmsh load sys config merge file /path/to/dg_swagwaf_jailbreak_patterns.conf
tmsh save sys config

# 2. Re-trigger RULE_INIT
tmsh modify ltm rule /Common/ADMIN-SwagWAF { }

# 3. Confirm auto-detection in /var/log/ltm
grep "SwagWAF:" /var/log/ltm | tail -5
# Expected: SwagWAF: dg_swagwaf_jailbreak_patterns loaded OK (68 patterns)

# 4. Re-run smoke tests — injection now goes through DG path
export VIP="https://claimqa.erp.fordham.edu"
bash examples/curl/test-swagwaf.sh

# 5. Confirm DG path in logs (no "dg=static_fallback" tag)
grep "SWAGWAF|INJECTION_ATTEMPT" /var/log/ltm | tail -5
```

For the trusted-source POC, deploy and read back the canonical IP group separately:

```bash
tmsh load sys config merge file /path/to/dg_swagwaf_trusted_sources.conf
tmsh list ltm data-group internal /Common/dg_swagwaf_trusted_sources
tmsh modify ltm rule /Common/ADMIN-SwagWAF { }
tmsh save sys config
```

Verify the expected host/CIDR, metadata value, initialization log, and HA config sync.

---

## ISA Evidence Checklist

| Evidence item | How to collect |
|---|---|
| iRule applies to VIP without errors | `tmsh list ltm virtual <vip> rules` + no `01070151` in ltm log |
| Static fallback active on bare deployment | `grep "SwagWAF:" /var/log/ltm` → `static fallback active (13 patterns)` |
| Injection attempt blocked + logged with XFF | `grep "SWAGWAF\|INJECTION_ATTEMPT" /var/log/ltm` |
| Rate limiting triggered + logged with XFF | `grep "SWAGWAF\|RATE_LIMITED\|BLOCKED" /var/log/ltm` |
| Security headers enforced | `curl -skI https://<vip>/ \| grep -E "Strict-Transport\|Cache-Control\|X-Content"` |
| Server fingerprint headers removed | `curl -skI https://<vip>/ \| grep -E "^Server:\|^X-Powered"` (should return nothing) |
| Smoke test suite passes | `bash examples/curl/test-swagwaf.sh` → `0 failed` |
| Trusted source matches canonical policy | `SWAGWAF\|TRUSTED_SOURCE` includes `matched=`, `policy=`, and `action=rate_limit_bypass` |
| Untrusted source remains limited | Burst produces `SWAGWAF\|RATE_LIMITED` or `SWAGWAF\|BLOCKED` |

---

## Known Issues / Open Items (260730)

| Issue | Status | Notes |
|---|---|---|
| TLS rejection test requires `--tls-max` flag | Open | macOS curl may not support `--tls-max`; use `openssl s_client -tls1_1` as alternative |
| iRule table timeout units | Open | Preserve the device-validated v0.3.8 behavior for release; correct timeout units and repeat save/compile plus controlled expiry validation in the next version |
| Trusted-source POC completion | Open | Confirm DG readback, untrusted negative test, policy metadata, and HA config sync |
| Lite-rule convergence | Open | Identify owner; do not create a second trusted-source policy |
