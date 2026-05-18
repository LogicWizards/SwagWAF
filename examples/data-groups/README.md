# SwagWAF — Data Groups

This directory contains reference material and examples for the BIG-IP data groups
that extend SwagWAF's intelligence without requiring iRule edits.

---

## Overview

SwagWAF's core protection is built into the iRule, but the detection patterns can be
externalised into BIG-IP **string data groups** (class match). This separates the
enforcement logic from the intelligence layer, allowing InfoSec and SIEM teams to
update threat feeds out of band through automation or CI/CD.

---

## Planned Data Groups

| Data Group Name | Type | Purpose |
|---|---|---|
| `dg_swagwaf_jailbreak_patterns` | string | LLM jailbreak / prompt injection phrases |
| `dg_swagwaf_sql_patterns` | string | SQL injection signatures |
| `dg_swagwaf_xss_patterns` | string | Cross-site scripting payloads |
| `dg_swagwaf_bad_ips` | address | Known malicious IP addresses |
| `dg_swagwaf_trusted_clients` | address | High-volume trusted clients (rate-limit bypass) |
| `dg_swagwaf_endpoint_limits` | string | Per-endpoint rate limit overrides |

---

## iRule Integration Pattern

```tcl
# Replace hardcoded pattern loop with a data group lookup
if {[class match $payload_lower contains dg_swagwaf_jailbreak_patterns]} {
    log local0. "INJECTION_ATTEMPT: [IP::client_addr] matched jailbreak data group"
    set v [table incr "viol:[IP::client_addr]" 3]
    table timeout "viol:[IP::client_addr]" $static::violation_window_ms
    HTTP::respond 400 content "{\"error\":\"invalid_request\",\"message\":\"Request rejected by security policy\"}" \
        "Content-Type" "application/json"
    return
}
```

---

## Per-Endpoint Rate Limit Override Pattern

Data group entry format: `<path> := <max_requests>:<window_ms>`

```text
/api/v1/chat/completions := 10:2000
/api/v1/embeddings := 50:2000
/api/v1/images/generations := 5:5000
```

iRule lookup:

```tcl
set path [HTTP::path]
set limit_str [class match -value $path equals dg_swagwaf_endpoint_limits]
if {$limit_str ne ""} {
    scan $limit_str "%d:%d" ep_max ep_window
} else {
    set ep_max $static::max_requests
    set ep_window $static::window_ms
}
```

---

## Automation Notes

- Data groups can be managed via the BIG-IP iControl REST API or `tmsh`
- Recommended update cadence: CI/CD pipeline triggered by threat feed refresh or Git push
- Keep a Git-managed canonical copy of each data group's entries as the source of truth
