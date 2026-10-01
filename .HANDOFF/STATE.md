# State: SwagWAF

```
# --------------------------------------------------------------------------
# NOTES:    STATE.md
# --------------------------------------------------------------------------
# ABSTRACT: Current v0.3.8 QA, release-wrap, evidence, and follow-up state.
# CREATED:  260518 BY: JN
# UPDATED:  260804 BY: Sol(GPT5.6)::Copilot:MAC-00
# VERSION:  0.3.8.1
# ARCHITECT: JN
# TECHLEAD: JN
# STAGE:    POST-RELEASE-DEVELOPMENT
# --------------------------------------------------------------------------
```

## Current Phase

v0.3.8 is published and tagged. The full `/Common/ADMIN-SwagWAF` rule consumes the canonical trusted-source IP data group, logs structured events through F5 Syslog Forwarding to Sumo Logic, and uses `table lookup -notouch` so blocked retries do not renew the block idle timeout.

The public `v0.3.8` tag points to a handoff-free snapshot. `main` contains a later cleanup commit removing stale `.HANDOFF` files introduced by the v0.3.7 merge. `dev` retains the complete development handoffs and post-release hardening work.

## Verified v0.3.8 Evidence

- Full-rule save/compile on BIG-IP 17.5, canonical-DG initialization, policy metadata, non-trusted rate limiting, DG readback, and HA sync were verified.
- Sumo received full-rule `TRUSTED_SOURCE` events after cutover.
- Authorized synthetic tests generated `INJECTION_ATTEMPT`, `BLOCKED`, and `BLOCKED_REPEAT` while trusted-source events continued, proving that the exception bypasses rate limiting without bypassing payload inspection.
- A built-in fallback phrase was rejected with HTTP 400. MEDIUM-tier phrases reached the backend with HTTP 404, consistent with the optional tiered jailbreak-pattern DG being absent, uninitialized, or missing those records on this VIP.
- PyST v0.1.4 discovered and ran `tests/python/test_post_deploy.py` through the working `/Users/jnegron9/DATA/miners/ipscan/pyst.py` runtime.
- Five offline parser tests in `tests/python/test_update_dg.py` passed, covering all 68 shipped records, escaped role keys, trusted-source metadata, and rejection of multiline and inline malformed records before destructive replacement.
- A 260731 `tmsh list ltm rule ADMIN-SwagWAF` scrape matched the release source's behavior-critical trusted-source, `-notouch`, timeout, and logging paths. HTML-rendered `&#8212;` sequences in pasted comments were treated as transport substitutions, not source changes.

## v0.3.8.1 Dev Runtime Evidence

- On 260804 the full enforcement barrage (`tests/swagwaf-barrage.sh`) ran against `claimqa.erp.fordham.edu` and produced: baseline pass (`404`), injection escalation `400 -> 403 -> 429` (`INJECTION_ATTEMPT -> BLOCKED -> BLOCKED_REPEAT`), a 140-request burst fully rejected while the IP block was active, a clean post-burst request returning `429` (IP-wide block confirmed), and a TLS 1.1 handshake rejection.
- Sumo confirmed the deployed rule emits the v0.3.8.1 per-event `policy` verdicts: `INJECTION_ATTEMPT policy="Threat Level: HIGH"`, `BLOCKED policy="Malicious Payload; Threat Level: HIGH; blocked 600 secs"`, and `BLOCKED_REPEAT policy="Active block; retry after 600 secs"`. The 429 body returned `retry_after: 600`, matching `static::block_seconds`.
- Those enforcement events logged `src=10.224.244.17` on `vip=CLAIMQA-F5_ERP_FORDHAM_EDU_443_FE_VIP` — the real VPN client, not the shared load-balancer/monitor source (`150.108.4.66`) seen on `TRUSTED_SOURCE` traffic — confirming the verified L4 peer is captured as the true source for directly connecting clients.
- Scope note: this validated direct-client capture and the per-event verdict schema on the live rule. A freshly compiled v0.3.8.1 still needs a controlled save/compile and a genuine proxy-scenario test to exercise `dg_swagwaf_trusted_proxies` XFF-based true-client derivation.
- Committed to `dev` as the v0.3.8.1 checkpoint. Changed paths: `src/iRule-SwagWAF.tcl`, `README.md`, `FAQ.md`, `tests/README.md`, `tests/swagwaf-barrage.sh`, `examples/data-groups/dg_swagwaf_trusted_proxies.conf`, `.gitignore`, and this file.

## Forensic Recovery Status

- No stash, unreachable commit, backup patch, rejected patch, or temporary source file contains missing work.
- The only unreachable Git object is an obsolete README draft superseded by the current README.
- All 22 paths changed by release-prep commit `f87ecf9` remain on `dev`; generated `.pyc`, `.pyo`, and `__pycache__` artifacts were intentionally removed.
- `.HANDOFF/SNAPSHOTS/iRule-SwagWAF-post-QA-260731.tcl` is the deployed v0.3.8 release form, not a backup of the later hardening. The hardening was recovered from the transcript and committed in `f62dfc8`.
- README test inventory and snapshot labeling were corrected during the forensic closeout. No substantive code or test source was found missing.

## Open Items

| ID | Item | Priority | Owner | Notes |
| --- | --- | --- | --- | --- |
| SW-23 | Validate corrected iRule table timeout units | High | Joe | Implemented on `dev`: millisecond timestamp arithmetic is separate from second-based `table` idle timeouts. Save/compile and repeat controlled expiry validation on BIG-IP 17.5 before promotion. |
| SW-24 | Benchmark with and without the iRule | Medium | Joe | Measure latency percentiles, throughput, errors, and TMM/CPU impact where available. |
| SW-25 | Verify optional tiered jailbreak-pattern DG | Low | Joe | Confirm `RULE_INIT` state and MEDIUM/LOW records before requiring tier-specific assertions. |
| SW-26 | Converge or retire `/Common/Admin-SwagWAF_lite` | Medium | Owner TBD | The independent variant must not gain a separate trusted-source policy. |
| SW-27 | Build selective public v0.3.8 release commit | Complete | Agent/Joe | Published tag `v0.3.8` without `.HANDOFF`; stale handoffs were subsequently removed from `main`. |
| SW-28 | Normalize the structured event envelope | Complete (dev) | Agent/ISA | Implemented on `dev`: every HTTP event logs one canonical `$swag_ctx` field set (`src`/`true_client`/`xff`/`client_xff`/`dst`/`vip`/`method`/`uri`) plus `policy`; injection `BLOCKED` events gained the missing `method`/`uri`. TLS handshake and response events keep their own field set because they fire outside the HTTP request context. Save/compile on BIG-IP 17.5 before promotion. |
| SW-29 | Repeat controlled block-expiry validation | Medium | Joe | Sumo identified the synthetic source as `10.224.244.7`; access later returned, but a VPN source change was not ruled out. Record source before block, during retry, and after expiry. |
| SW-30 | Decide whether XFF-derived `true_client` drives enforcement | High | Joe/ISA | `dev` derives `true_client` from the left-most XFF only when the L4 peer is in optional `/Common/dg_swagwaf_trusted_proxies`, and uses it for LOGGING only. Open policy question: if real user traffic arrives through a proxy that is also a trusted source, those users currently bypass rate limiting entirely. Decide whether rate-limit keys and trusted-source matching should switch from the L4 peer to `true_client`. Do not change enforcement without ISA sign-off and device validation. |
| SW-31 | Validate left-to-right XFF `true_client` capture behind a real proxy | High | Joe | Not started. Stand up a Podman + NGINX reverse proxy in front of the SwagWAF VIP with `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`. Add the proxy egress IP to `/Common/dg_swagwaf_trusted_proxies` and re-init the rule. Positive test: send a spoofed left-most XFF (e.g. `1.2.3.4, <proxy>`) and confirm SIEM shows `true_client=1.2.3.4` with `src=<proxy>`. Negative test: remove the proxy from the DG and confirm `true_client` falls back to the verified L4 peer (XFF ignored). This proves the v0.3.8.1 proxy-scenario path that the 260804 direct-client barrage did not exercise. |

## Provisional Expiry Evidence

The 260731 Sumo query separated trusted monitor sources from the synthetic client. The monitor addresses `150.108.2.177`, `150.108.2.153`, and `150.108.4.66` emitted named trusted policies; synthetic tests came from untrusted source `10.224.244.7` with `policy=N/A` and generated two `INJECTION_ATTEMPT`, one `BLOCKED`, and two `BLOCKED_REPEAT` events. Access to `claimqa.erp.fordham.edu` later returned. This is consistent with block expiry and `-notouch`, but remains provisional because the VPN reconnect may have changed the client address.

## Release Decision

Plain `v0.3.8` is published. Keep `.HANDOFF` on `dev`; do not add it back to `main` or future public release trees.

## Next Action

Save/compile v0.3.8.1 on BIG-IP 17.5 (SW-23), then run the SW-31 Podman + NGINX proxy harness to validate left-to-right XFF `true_client` capture, and complete SW-29 controlled expiry testing on `dev`. Do not change enforcement keying (SW-30) without ISA sign-off.
