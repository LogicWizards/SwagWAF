# Session: v0.3.8.1 Per-Event Policy Verdict, Barrage Suite, and Live Validation

```
# --------------------------------------------------------------------------
# NOTES:    README.md
# --------------------------------------------------------------------------
# ABSTRACT: Immutable SBAR record of the v0.3.8.1 dev work — per-event policy
#     verdicts, config-derived retry_after, the full-enforcement barrage
#     script, trusted-proxies data group, doc updates, and the 260804 live
#     SIEM-validated barrage against the CLAIMQA QA VIP.
# CREATED:  260805 BY: Sol(Opus4.8)::Copilot:MAC-00
# UPDATED:  260805 BY: Sol(Opus4.8)::Copilot:MAC-00
# VERSION:  0.3.8.1
# ARCHITECT: JN
# TECHLEAD: JN
# STAGE:    CLOSED
# --------------------------------------------------------------------------
```

## SBAR

**Situation:** The assistant model was switched mid-thread. The operator reported that
Sumo `src` always showed a load-balancer/monitor address rather than the true client,
and asked for a consistent `policy` field across every event instead of only
`TRUSTED_SOURCE`. The session became a code review, a runtime validation, and a
release-quality checkpoint of the `dev` hardening line.

**Background:** `v0.3.8` was already published. `dev` carried post-release schema
unification (canonical `$swag_ctx`, optional `dg_swagwaf_trusted_proxies` for XFF-based
`true_client` derivation, seconds-based table timeouts, XFF/URI sanitation). The
operator needed evidence that SwagWAF blocks and that its logs are ISA-parseable
regardless of the event that fired, ahead of Fordham ISA prod-readiness review.

**Assessment:**
- The `src` concern was a misread, not a bug: `src` is the verified L4 TCP peer. The
  three fixed addresses were real monitor/proxy peers connecting directly. True upstream
  identity only exists in XFF, already captured as `client_xff` and (for vetted proxies)
  derived into `true_client`.
- Code review produced `v0.3.8.1`: every event now carries an actionable quoted
  `policy="..."` verdict (no `N/A` fall-through), and every 429 `retry_after` derives
  from `static::block_seconds` / `static::window_seconds` instead of hardcoded literals.
- A full-enforcement barrage script was added and run against the QA VIP from an
  untrusted egress. It exercised every path and produced real blocks.
- Sumo confirmed the deployed rule already emits the `v0.3.8.1` verdict strings and that
  enforcement events logged the operator's real VPN client as `src`, proving true-source
  capture for directly connecting clients.

**Recommendation:**
1. Save/compile `v0.3.8.1` on BIG-IP 17.5 (SW-23) before promotion beyond `dev`.
2. Stand up the SW-31 Podman + NGINX proxy harness to validate left-to-right XFF
   `true_client` capture (positive and negative), which the direct-client barrage did
   not exercise.
3. Complete SW-29 controlled block-expiry validation.
4. Do not switch rate-limit keying to `true_client` (SW-30) without ISA sign-off.

## Artifacts

- `src/iRule-SwagWAF.tcl` — `v0.3.8.1`: per-event `policy` verdict; config-derived `retry_after`.
- `tests/swagwaf-barrage.sh` — full enforcement-path barrage; takes the FQDN as `$1`, run with `bash`.
- `examples/data-groups/dg_swagwaf_trusted_proxies.conf` — optional vetted-proxy list for XFF true-client derivation.
- `README.md`, `FAQ.md`, `tests/README.md` — updated for `v0.3.8.1`, the trusted-proxies DG, and the barrage.
- `.gitignore` — ignores Python bytecode (`__pycache__/`, `*.py[cod]`).
- `.HANDOFF/STATE.md` — `v0.3.8.1` runtime evidence and open items (added SW-31).

## Decisions

- `policy` is a required field on every SWAGWAF event; the baseline is `inspect`, a
  trusted match carries governance metadata, and each enforcement branch sets its own
  verdict. `N/A` fall-through was removed as non-actionable.
- `retry_after` must reflect configured policy, not literals.
- The trusted-proxies XFF derivation is LOGGING ONLY; rate-limit enforcement still keys
  on the verified L4 peer pending the SW-30 ISA decision.

## Validation Evidence

- `260804` barrage against `claimqa.erp.fordham.edu` from an untrusted egress:
  baseline pass (`404`), injection escalation `400 -> 403 -> 429`
  (`INJECTION_ATTEMPT -> BLOCKED -> BLOCKED_REPEAT`), a 140-request burst fully rejected
  while the IP block was active, a clean post-burst request returning `429` (IP-wide
  block confirmed), and a TLS 1.1 handshake rejection.
- Sumo aggregates confirmed live verdict strings: `INJECTION_ATTEMPT policy="Threat Level: HIGH"`,
  `BLOCKED policy="Malicious Payload; Threat Level: HIGH; blocked 600 secs"`, and
  `BLOCKED_REPEAT policy="Active block; retry after 600 secs"`, with the 429 body
  returning `retry_after: 600`.
- Enforcement events logged `src=10.224.244.17` on `vip=CLAIMQA-F5_ERP_FORDHAM_EDU_443_FE_VIP`,
  the operator's real VPN client, distinct from the shared `150.108.4.66` monitor seen
  on `TRUSTED_SOURCE` traffic.
- `info complete` confirmed the iRule is brace/bracket/quote balanced. Markdown headers
  and `git diff --check` passed on all committed docs.

## Commits

- `ed96ca5` feat(swagwaf): v0.3.8.1 per-event policy verdict, config-derived retry_after, barrage suite
- `27f33ef` docs(handoff): add SW-31 proxy XFF validation and refresh next action

## Lessons

- The barrage exercised the **live deployed** rule, not a freshly compiled `v0.3.8.1`;
  SIEM verdicts happened to match because the deployed rule already carried the change.
  Do not treat a runtime pass as proof that the working-tree source is what is running.
- Direct-client `src` capture is proven; proxy-scenario `true_client` derivation is not,
  and must not be claimed until SW-31 runs.
- A session that produces commits must also produce this SBAR before it is declared
  done. This record was created retroactively because the wrap had no enforcing trigger.
