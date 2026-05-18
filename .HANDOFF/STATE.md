# State: SwagWAF

**Last updated:** 2026-05-18 (session close)
**Session:** 260518-swagwaf-polish
**Branch:** `dev` (created this session — future work goes here)

---

## Current phase

v0.3.1 tagged, released, and pushed to `main`. All v0.3.0/v0.3.1 polish work is
committed. `dev` branch created from `main` HEAD as the working branch going forward.
One user-owned README.md change is uncommitted (WIP — see open items).

---

## Open items

| ID | Item | Priority | Owner | Notes |
|---|---|---|---|---|
| SW-01 | Commit README.md tagline polish | Medium | Joe | User's WIP change: collapsed 3-line tagline + added "FREE BEER!" note + `<-- HEAVY LIFTING HERE` in file tree. Looks intentional — commit when satisfied. |
| SW-02 | PORTS note in test-commands.md | Low | Agent | Deferred this session. A note about which ports the tests assume (443? 8443?) should be added to `examples/curl/test-commands.md`. |
| SW-03 | Static fallback list audit | Low | Agent | The 8-entry built-in fallback list in the iRule predates the data group. Now that `dg_swagwaf_jailbreak_patterns` covers 54 patterns across 3 tiers, consider trimming the static list to a minimal "always-on" subset (HIGH-only, or remove overlap with DG). |
| SW-04 | GitHub Actions lint/validate | Low | Agent | `.github/workflows/` exists but is likely empty. A minimal workflow that validates Tcl syntax or lints the data-group conf would improve contribution safety. |

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
