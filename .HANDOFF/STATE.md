# State: SwagWAF

```
# --------------------------------------------------------------------------
# NOTES:    STATE.md
# --------------------------------------------------------------------------
# ABSTRACT: Current v0.3.8 QA, release-wrap, evidence, and follow-up state.
# CREATED:  260518 BY: JN
# UPDATED:  260731 BY: Sol(GPT5.6)::Copilot:MAC-00
# VERSION:  0.3.8
# ARCHITECT: JN
# TECHLEAD: JN
# STAGE:    RELEASE-CANDIDATE
# --------------------------------------------------------------------------
```

## Current Phase

v0.3.8 is in a QA pilot on BIG-IP 17.5 and is being wrapped for public release. The full `/Common/ADMIN-SwagWAF` rule consumes the canonical trusted-source IP data group, logs structured events through F5 Syslog Forwarding to Sumo Logic, and uses `table lookup -notouch` so blocked retries do not renew the block idle timeout.

Committed history is linear: `main` is an ancestor of `dev` and has no unique commits. The release risk is content selection, not branch-conflict resolution. The public release must exclude `.HANDOFF` and other AI-development context.

## Verified v0.3.8 Evidence

- Full-rule save/compile on BIG-IP 17.5, canonical-DG initialization, policy metadata, non-trusted rate limiting, DG readback, and HA sync were verified.
- Sumo received full-rule `TRUSTED_SOURCE` events after cutover.
- Authorized synthetic tests generated `INJECTION_ATTEMPT`, `BLOCKED`, and `BLOCKED_REPEAT` while trusted-source events continued, proving that the exception bypasses rate limiting without bypassing payload inspection.
- A built-in fallback phrase was rejected with HTTP 400. MEDIUM-tier phrases reached the backend with HTTP 404, consistent with the optional tiered jailbreak-pattern DG being absent, uninitialized, or missing those records on this VIP.
- PyST v0.1.4 discovered and ran `tests/python/test_post_deploy.py` through the working `/Users/jnegron9/DATA/miners/ipscan/pyst.py` runtime.
- A 260731 `tmsh list ltm rule ADMIN-SwagWAF` scrape matched the release source's behavior-critical trusted-source, `-notouch`, timeout, and logging paths. HTML-rendered `&#8212;` sequences in pasted comments were treated as transport substitutions, not source changes.

## Open Items

| ID | Item | Priority | Owner | Notes |
| --- | --- | --- | --- | --- |
| SW-23 | Correct and validate iRule table timeout units | High | Agent/Joe | v0.3.8 preserves the device-validated 260730 Tcl. For the next version, separate millisecond timestamp arithmetic from second-based `table` idle timeouts, then save/compile and repeat controlled expiry validation on BIG-IP 17.5. |
| SW-24 | Benchmark with and without the iRule | Medium | Joe | Measure latency percentiles, throughput, errors, and TMM/CPU impact where available. |
| SW-25 | Verify optional tiered jailbreak-pattern DG | Low | Joe | Confirm `RULE_INIT` state and MEDIUM/LOW records before requiring tier-specific assertions. |
| SW-26 | Converge or retire `/Common/Admin-SwagWAF_lite` | Medium | Owner TBD | The independent variant must not gain a separate trusted-source policy. |
| SW-27 | Build selective public v0.3.8 release commit | High | Agent/Joe | Exclude `.HANDOFF`, generated files, and AI-development artifacts; review before commit or tag. |
| SW-28 | Normalize and sanitize the structured event envelope | High | Agent/ISA | Make `policy`, `reason`, and `threat` queryable on every event using explicit neutral values when not applicable; sanitize client-supplied URI/XFF values; preserve backward-compatible event names. Defer implementation until after v0.3.8. |
| SW-29 | Repeat controlled block-expiry validation | Medium | Joe | Sumo identified the synthetic source as `10.224.244.7`; access later returned, but a VPN source change was not ruled out. Record source before block, during retry, and after expiry. |

## Provisional Expiry Evidence

The 260731 Sumo query separated trusted monitor sources from the synthetic client. The monitor addresses `150.108.2.177`, `150.108.2.153`, and `150.108.4.66` emitted named trusted policies; synthetic tests came from untrusted source `10.224.244.7` with `policy=N/A` and generated two `INJECTION_ATTEMPT`, one `BLOCKED`, and two `BLOCKED_REPEAT` events. Access to `claimqa.erp.fordham.edu` later returned. This is consistent with block expiry and `-notouch`, but remains provisional because the VPN reconnect may have changed the client address.

## Release Decision

Release plain `v0.3.8`; pre-1.0 status already communicates API maturity. Keep `.HANDOFF` on `dev`, include public code, examples, tests, FAQ, README, and operator documentation, and pause for exact file-set review before commit, tag, merge, or push.

## Next Action

Run the final offline gate, create the already-approved selective public release commit without `.HANDOFF`, verify the commit tree, tag plain `v0.3.8`, and push. Preserve SW-23, SW-28, and SW-29 on `dev` for the next version.
