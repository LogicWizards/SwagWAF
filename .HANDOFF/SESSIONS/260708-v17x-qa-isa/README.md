---
date: 2026-07-08 / 2026-07-14
author: jnegron9
session: v17x-qa-isa
branch: dev
versions: v0.3.2 → v0.3.7
---

# SESSION — SwagWAF v17.x QA / ISA Validation (260708–260714)

---

## SBAR

**Situation:** ISA approved SwagWAF for QA testing against a Fordham BIG-IP v17.1
deployment. The published iRule immediately hit a parse error (`matches_regex` removed
in v17.x) and could not be applied to a VIP. Multiple cascading issues surfaced
through the QA cycle.

**Background:** SwagWAF v0.3.1 was written and tested against BIG-IP v15/v16 and
relied on `matches_regex` as a `class match` operator (removed in v17.x), `-element`
for DG key lookup (returns `{name value}` list, not the key string), and literal data
group names in iRule source (BIG-IP validates these at VIP-assignment time — cannot
be applied without the DG existing). The DG was documented as optional but was actually
a hard deployment prerequisite under v17.x.

**Assessment:**
- All blocking issues resolved. iRule applies to VIP without errors and with no DG deployed.
- Static fallback (13 patterns) active and logging in production mode (`debug=0`).
- ISA security logging fully structured with src/dst IP:PORT, XFF, client_xff (spoofing
  signal), vip, method, uri, phrase, threat — Sumo Logic parseable.
- The link-time validation root cause (BIG-IP validates literal DG names at VIP-assignment
  time, not runtime) is documented in repo memory and iRule comments.
- debug=0 set. Ready for prod promotion PR.

**Recommendation:**
1. Push current `dev` to `origin/dev` (commit message drafted in session).
2. Open PR `dev` → `main` to release v0.3.7 (closes SW-06).
3. ISA to validate Sumo Logic query output against `_sourceCategory=qa/security/lb/f5`.
4. Test injection detection in isolation — IP was blocked during rate-limit test;
   clear table with `tmsh delete ltm table all` (QA only) before injection test.

---

## What was accomplished

| Item | Version | Status |
|---|---|---|
| `matches_regex` → `contains` (v17.x compat) | v0.3.2 | ✅ |
| 6 PCRE alternation DG entries expanded to literals | v0.3.2 | ✅ |
| `-element` → `-name` in DG lookup (tier detection fix) | v0.3.2 | ✅ |
| Structured `SWAGWAF\|EVENT\|` logging replacing positional format | v0.3.2 | ✅ |
| Static fallback expanded 8 → 13 patterns (ignore/disregard variants) | v0.3.2 | ✅ |
| Variable DG name (`$static::dg_name`) bypasses link-time VIP validation | v0.3.2 | ✅ |
| `catch {class size $static::dg_name}` auto-detection at RULE_INIT | v0.3.2 | ✅ |
| `<DEBUG>` positional logs → `SWAGWAF\|TRACE\|` key=value format | v0.3.6 | ✅ |
| `dst=[IP::local_addr]` added to all log lines | v0.3.6 | ✅ |
| `client_xff=` pre-sanitization XFF capture (spoofing indicator) | v0.3.6 | ✅ |
| `src=IP:PORT` / `dst=IP:PORT` format per ISA feedback | v0.3.7 | ✅ |
| `static::debug 0` — production mode | v0.3.7 | ✅ |
| `docs/testing-v17.1.md` — v17.x QA validation guide + Sumo Logic queries | — | ✅ |
| `examples/curl/test-swagwaf.sh` — bash assertion suite | — | ✅ |

---

## Key technical finding: BIG-IP link-time DG validation

BIG-IP validates **literal** data group names in `class` operations at VIP-assignment
time — not runtime. `catch`, `class exists`, and `if` guards are all irrelevant because
the error fires before any Tcl executes. Workaround: store the DG name in a variable
(`set static::dg_name "dg_swagwaf_jailbreak_patterns"`) and reference via `$static::dg_name`.
BIG-IP cannot validate variable-referenced names statically. Documented in repo memory
(`F5-gslb-dns-governance.md`). Cost of discovery: ~8hr / ~860 credits.

---

## Open items at session close

| ID | Item | Priority | Notes |
|---|---|---|---|
| SW-06 | PR `dev` → `main` + release v0.3.7 | High | Commit drafted; push and PR pending user action |
| SW-ISA-01 | ISA injection test (isolated) | High | Clear block table first: `tmsh delete ltm table all` (QA only) |
| SW-ISA-02 | Sumo Logic query validation with ISA | Medium | `_sourceCategory=qa/security/lb/f5 "SWAGWAF\|"` |
| SW-ISA-03 | Deploy `dg_swagwaf_jailbreak_patterns` to activate 3-tier detection | Medium | `tmsh load sys config merge file dg_swagwaf_jailbreak_patterns.conf` → `tmsh modify ltm rule SwagWAF { }` |
| SW-04 | GitHub Actions lint/validate | Low | `.github/workflows/` still empty |
