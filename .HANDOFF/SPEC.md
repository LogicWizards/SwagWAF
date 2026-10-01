# Spec: Trusted-Source Policy POC

```
# --------------------------------------------------------------------------
# NOTES:    SPEC.md
# --------------------------------------------------------------------------
# ABSTRACT: Acceptance criteria for the v0.3.8 trusted-source data-group POC
#     on the full SwagWAF iRule and its governed automation path.
# CREATED:  260730 BY: JN
# UPDATED:  260731 BY: Sol(GPT5.6)::Copilot:MAC-00
# VERSION:  0.3.8
# ARCHITECT: JN
# TECHLEAD: JN
# --------------------------------------------------------------------------
```

## Acceptance Criteria

- [x] Full iRule uses one canonical variable-referenced IP data group:
  `/Common/dg_swagwaf_trusted_sources`.
- [x] Missing trusted-source DG disables only the bypass and does not prevent VIP assignment.
- [x] Host and CIDR records are supported by an internal `type ip` data group.
- [x] Matching sources bypass rate limiting only; remaining SwagWAF controls still execute.
- [x] Pre-existing `block:<ip>` and `viol:<ip>` state is removed when a source becomes trusted.
- [x] ISA receives `SWAGWAF|TRUSTED_SOURCE` with source, matched record, policy metadata,
  destination, VIP, method, URI, and action.
- [x] Block checks use `table lookup -notouch` so retries do not renew block idle timeout.
- [x] Repository includes a deployable trusted-source DG artifact with owner/service/ticket/expiry metadata.
- [x] `update-dg.py` derives `type ip` or `type string` and preserves quoted metadata values.
- [x] Save/compile the full iRule on BIG-IP 17.5 with the canonical DG deployed.
- [x] Verify DG initialization, bypass event, record metadata, and no new rate-limit block for the POC source.
- [x] Verify non-trusted traffic still rate-limits.
- [x] Read back the deployed DG and confirm HA config sync.
- [x] Verify trusted-source synthetic requests still exercise payload inspection; Sumo
  recorded `TRUSTED_SOURCE`, `INJECTION_ATTEMPT`, `BLOCKED`, and `BLOCKED_REPEAT`.
- [ ] Complete the QA pilot, validate timeout units, and feed operational findings back
  into the next release rather than treating those tuning items as a v0.3.8 blocker.
- [ ] Benchmark a comparable VIP with and without SwagWAF. Record latency percentiles,
  throughput, errors, and TMM/CPU impact where available.

## POC Boundary

`/Common/Admin-SwagWAF_lite` remains unchanged during this POC. Its throttling events
are evidence for owner engagement and later convergence, not permission to create a
second policy list.
