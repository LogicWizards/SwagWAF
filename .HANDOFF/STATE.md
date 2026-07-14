# State: SwagWAF

**Last updated:** 260714
**Session:** 260708-v17x-qa-isa
**Branch:** `dev` — uncommitted changes staged for push to `origin/dev`
**Version:** 0.3.7 (debug=0, production-ready)

---

## Current phase

v0.3.7 on `dev`. ISA QA testing in progress against Fordham BIG-IP v17.1 (QA env:
`claimqa.erp.fordham.edu`). iRule applies to VIP cleanly. Static fallback active (no
DG deployed yet). Rate-limit and TRACE logging confirmed in Sumo Logic. Injection test
pending (IP blocked during rate-limit test — clear table before testing). Ready to push
`dev` → `origin/dev` and open PR to `main`.

---

## Open items

| ID | Item | Priority | Owner | Notes |
|---|---|---|---|---|
| SW-06 | PR `dev` → `main` + release v0.3.7 | High | Joe | Commit message drafted. Push + PR pending. |
| SW-ISA-01 | ISA injection detection test (isolated) | High | Joe | Clear block table first: `tmsh delete ltm table all` (QA only). Expect HTTP 400 + `SWAGWAF\|INJECTION_ATTEMPT` in Sumo Logic. |
| SW-ISA-02 | Sumo Logic query validation | Medium | Joe/ISA | `_sourceCategory=qa/security/lb/f5 "SWAGWAF\|"` — confirm all event types visible. |
| SW-ISA-03 | Deploy DG to activate 3-tier detection | Medium | Joe | `tmsh load sys config merge file dg_swagwaf_jailbreak_patterns.conf` → `tmsh modify ltm rule SwagWAF { }` → confirm `loaded OK (65 patterns)` in log. |
| SW-04 | GitHub Actions lint/validate | Low | Agent | `.github/workflows/` still empty. |

---

## Completed (this project)

| Item | Version | Notes |
|---|---|---|
| Core iRule — TLS, rate-limit, injection detection | v0.1–v0.2 | Contest entry |
| AppWorld 2026 Budget Bodyguard Award | v0.2.6 | GitHub Release created |
| Repo restructure (src/, examples/, docs/, .github/) | v0.3.0 | |
| Data group-based threat detection (HIGH/MEDIUM/LOW) | v0.3.0 | 54 PCRE patterns |
| `update-dg.py` iControl REST push tool | v0.3.0 | |
| DG rename → `dg_swagwaf_jailbreak_patterns` namespace | v0.3.1 | |
| `RULE_INIT` DG availability check (static flag) | v0.3.1 | |
| v17.x compat: `matches_regex` → `contains` | v0.3.2 | PCRE alternation entries expanded to literals |
| Tier detection fix: `-element` → `-name` | v0.3.2 | HIGH/MEDIUM/LOW now resolves correctly |
| Variable DG name bypasses BIG-IP link-time VIP validation | v0.3.2 | Root cause: literal names validated at VIP-assign time, not runtime |
| Auto-detect DG via `catch {class size $static::dg_name}` | v0.3.2 | No manual flag flip required |
| Static fallback expanded 8 → 13 patterns | v0.3.2 | ignore/disregard variants added |
| Structured `SWAGWAF\|TRACE\|` logging (replaced `<DEBUG>` positional) | v0.3.6 | Sumo Logic field-parseable |
| `dst=` and `client_xff=` fields (spoofing detection) | v0.3.6 | src≠client_xff = XFF spoofing attempt |
| `src=IP:PORT` / `dst=IP:PORT` format | v0.3.7 | Per ISA feedback for web server log correlation |
| `debug=0` production default | v0.3.7 | TRACE logs silenced; security events always log |
| `docs/testing-v17.1.md` — v17.x QA guide + Sumo Logic queries | — | |
| `examples/curl/test-swagwaf.sh` — bash assertion suite | — | CI/CD compatible |
| SW-02: test-commands.md VIP variable (`$VIP="https://..."`) | dev | |
| SW-03: Static fallback audit | v0.3.2 | Expanded and synced with DG ignore/disregard variants |

---

---

## Current phase

v0.3.1 on `main`. Active work on `dev`. README expanded with architecture positioning,
known limitations, and roadmap sections in preparation for a call with an F5 Principal
PM (F5XC WAAP, Gen AI roadmap). Call may be today (2026-05-21). `dev` commits are
local-only pending push approval.

---

## Open items

| ID | Item | Priority | Owner | Notes |
|---|---|---|---|---|
| ~~SW-05~~ | ~~Push `dev` to `origin/dev`~~ | ~~High~~ | ~~Joe~~ | ✅ Done 2026-05-21. `e1693df..2648be2` pushed to `origin/dev`. |
| SW-06 | PR `dev` → `main` + release v0.3.2 | Medium | Joe | After PM call — README additions warrant a patch release so main reflects current docs. |
| SW-02 | PORTS note in test-commands.md | Low | Agent | Deferred. Add a callout near the top of `examples/curl/test-commands.md` documenting expected port (443 or 8443). |
| SW-03 | Static fallback list audit | Low | Agent | The 8-entry built-in fallback list predates the DG. Consider trimming to HIGH-only or removing DG overlap. |
| SW-04 | GitHub Actions lint/validate | Low | Agent | `.github/workflows/` exists but likely empty. |

---

## Backlog (future enhancements)

| ID | Task | Notes |
|---|---|---|
| SW-10 | Additional data group patterns | `dg_swagwaf_*` namespace is established — future DGs for other categories (e.g., PII patterns, known-bad UAs) can drop in without iRule changes |
| SW-11 | Rate-limit per-endpoint support | Currently global violation counter. Per-VIP or per-URI threshold would reduce false positives on high-traffic endpoints. |
| SW-12 | `update-dg.py` dry-run flag | `--dry-run` mode: parse conf, validate patterns, print what would be PUT/POSTed — without hitting BIG-IP. Useful for CI. |
| SW-13 | BYOD pattern for update-dg.py | Script already derives DG name from conf header — document the pattern so others can reuse it for non-jailbreak DGs. |

---

## Completed (this project)

| Item | Version | Notes |
|---|---|---|
| Core iRule — TLS, UA, rate-limit, injection detection | v0.1.x–v0.2.x | Contest entry |
| AppWorld 2026 Budget Bodyguard Award | v0.2.6 | GitHub Release created |
| Repo restructure (src/, examples/, docs/, .github/) | v0.3.0 | `iRule-SwagWAF.tcl` filename de-versioned |
| Data group-based threat detection (HIGH/MEDIUM/LOW) | v0.3.0 | `dg_swagwaf_jailbreak_patterns`, 54 PCRE patterns |
| `update-dg.py` iControl REST push tool | v0.3.0 | stdlib-only; upsert (PUT→POST fallback) |
| DG rename: `dg_injection_phrase` → `dg_swagwaf_jailbreak_patterns` | v0.3.1 | GUI readability, `dg_swagwaf_*` namespace |
| `RULE_INIT` DG availability check (static flag) | v0.3.1 | Eliminated per-request `catch` overhead |
| `update-dg.py` future-proofed (conf as arg, name from header) | v0.3.1 | Works for any `dg_swagwaf_*.conf` |
| `static::debug` default → 0 | v0.3.1 | Opt-in for deployment verification |
| test-commands.md rewritten (3-tier, correct responses) | v0.3.1 | HIGH→403 (not 400); MEDIUM→400; LOW→200+log |
| GitHub Releases for v0.3.0 and v0.3.1 | — | Both have release pages; v0.3.1 marked latest |
| `dev` branch created | — | Future work off `dev`; PRs back to `main` |
| README: architecture positioning + known limitations + expanded roadmap | dev/0f0feaa | Added 2026-05-21 for F5 PM call prep |
| SW-01: README tagline polish committed | dev/0f0feaa | User's WIP (FREE BEER, </br> tagline, file tree annotation) included in same commit |

---

## F5 PM Call Context (2026-05-21)

**Who:** Principal PM, F5 — owns F5XC WAAP Gen AI product roadmap (Jul 2024–present, SF Bay Area)

**Key framing established this session:**
- SwagWAF = network perimeter (BIG-IP LTM, HTTP proxy layer, PCRE)
- F5 AI Guardrails = inference layer (CalypsoAI acquisition, $180M, Sep 2025, ML-based)
- These are **complementary layers**, not competing products
- F5XC WAAP is his platform — different from BIG-IP AWAF
- Cloudflare displacement risk: app owners self-funding edge WAF when F5XC/BIG-IP VE can't be justified
- Cloud-native billing opacity: ALB+WAF+API GW costs spread across 5 line items look "free"; BIG-IP VE is one visible line item and easier to challenge in budget review
- SwagWAF fills the gap for BIG-IP shops that have the platform but not the enterprise WAF budget

**Strong cards for the call:**
1. Practitioner proof of the demand signal (built it before CalypsoAI acquisition)
2. Cloudflare bleed pattern — real F5 accounts losing WAAP revenue to self-funded Cloudflare
3. BIG-IP VE on Azure/AWS cost justification problem (TCO math vs. opaque cloud-native billing)
4. InfoSec governance angle — DG-based pattern management keeps InfoSec in control without iRule access

**Question to ask him:** Is F5XC WAAP designed to eventually replace BIG-IP AWAF for this use case, or are they expected to coexist long-term?
