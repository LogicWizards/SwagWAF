# Session: BIG-IP 17.5 Rate-Limit Incident and Trusted DG POC

```
# --------------------------------------------------------------------------
# NOTES:    README.md
# --------------------------------------------------------------------------
# ABSTRACT: SBAR record of the 260730 QA monitor-blocking incident, table
#     timeout diagnosis, v0.3.8 trusted-source design, and governance roadmap.
# CREATED:  260730 BY: JN
# UPDATED:  260731 BY: Sol(GPT5.6)::Copilot:MAC-00
# VERSION:  0.3.8
# ARCHITECT: JN
# TECHLEAD: JN
# STAGE:    ACTIVE
# --------------------------------------------------------------------------
```

## SBAR

**Situation:** After F5QA-RH01 was upgraded from BIG-IP 17.1 to 17.5, monitoring
sources generated repeated requests across many QA VIPs. SwagWAF blocked the sources,
causing monitor failures and risking on-call alerts. The full rule and an independently
created lite variant were both active.

**Background:** v0.3.7 keyed request, violation, and block state only by source IP.
The default threshold was 10 requests per 2-second window, five violations before block,
and a nominal 600-second block idle timeout. No trusted-source data group was deployed.

**Assessment:**

- `150.108.4.66` generated `HEAD /` requests across many VIPs and behaves like a WUG relay.
- `150.108.2.177` generated `GET /ibi_apps/signin` through `/Common/Admin-SwagWAF_lite`.
- `150.108.2.153` generated repeated `GET /` requests against X411QA.
- `table lookup "block:$ip"` touched the block entry on each retry, renewing its idle
  timeout indefinitely. `table lookup -notouch` corrects that behavior.
- Raising `max_requests` does not remove an already-active block entry.
- Reloading config re-runs `RULE_INIT` but does not purge TMM table state.
- Generic iRule table state is not exposed as a `show ltm table` tmsh module; prior
  repository guidance claiming otherwise was invalid.
- Logs proved `/Common/ADMIN-SwagWAF` initialized and generated
  `SWAGWAF|TRUSTED_SOURCE` events for the monitoring network.
- Multiple rule variants create policy drift; one canonical DG is the convergence point.

**Recommendation:**

1. Deploy and validate `/Common/dg_swagwaf_trusted_sources` with the full rule only.
2. Confirm matched record metadata in ISA logs and normal limiting for non-trusted traffic.
3. Read back the DG and verify HA sync.
4. Use continuing lite-rule throttling as evidence to engage its owner and converge on the
   shared policy object.
5. Build governed desired-state automation before exposing app-owner self-service intake.

## Artifacts

- `src/iRule-SwagWAF.tcl`: v0.3.8 canonical trusted-source DG consumer and `-notouch` block check.
- `examples/data-groups/dg_swagwaf_trusted_sources.conf`: IP DG POC with audit metadata.
- `examples/data-groups/update-dg.py`: derives DG type and parses quoted metadata values.
- `.HANDOFF/{FEATURE,SPEC,DESIGN,ROADMAP,STATE,PROTOCOL}.md`: project-local context system.

## Validation Evidence

- Full rule `RULE_INIT`: 260730 21:45:31 EDT on F5QA-RH01.
- `SWAGWAF|TRUSTED_SOURCE` events showed `150.108.4.66` matching
  `150.108.4.0/24` across multiple VIPs.
- Local parser test returned DG metadata `('Common', 'dg_swagwaf_trusted_sources', 'ip')`
  and preserved the complete policy value.
- User-reported device validation confirmed full-rule save/compile on BIG-IP 17.5,
  trusted-source initialization and metadata, continued non-trusted rate limiting,
  deployed-DG readback, and HA config sync.
- F5 Syslog Forwarding delivered SwagWAF events to Sumo Logic. Authorized synthetic
  tests on 260731 used SIEM-visible `A2M8-SWAGWAF--TEST-<testname>-<username>` markers;
  Sumo recorded two `INJECTION_ATTEMPT`, one `BLOCKED`, and two `BLOCKED_REPEAT`
  events while `TRUSTED_SOURCE` events continued.
- A static-fallback phrase returned HTTP 400. MEDIUM-tier data-group-only phrases
  reached the backend with HTTP 404, consistent with the optional tiered jailbreak DG
  being absent, uninitialized, or missing the expected records.
- The working PyST v0.1.4 runtime discovered and executed the post-deploy suite. The
  promoted standalone `wwwizards/pyst` CLI remains a separate pending MVx.

## Lessons

- Validate F5 CLI syntax against the target TMOS device or official command reference.
- A configured timeout is not an absolute lifetime when lookups touch the table entry.
- Separate policy from enforcement before multiplying rule variants.
- Operational incident findings belong in immutable session evidence and current design,
  not only in chat transcripts.
