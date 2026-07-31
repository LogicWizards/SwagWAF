# Design: SwagWAF

```
# --------------------------------------------------------------------------
# NOTES:    DESIGN.md
# --------------------------------------------------------------------------
# ABSTRACT: Append-only architectural decisions for SwagWAF enforcement,
#     trusted-source governance, logging, and rule-variant convergence.
# CREATED:  260730 BY: JN
# UPDATED:  260730 BY: JN
# VERSION:  0.3.8
# ARCHITECT: JN
# TECHLEAD: JN
# --------------------------------------------------------------------------
```

## D-01: One Canonical Trusted-Source Policy

All supported SwagWAF variants consume `/Common/dg_swagwaf_trusted_sources`.
Independent inline IP lists or per-variant trusted-source data groups are prohibited.
They create divergent policy, duplicated approvals, and exponential deployment states.

The canonical object is an internal BIG-IP `type ip` data group. Records may be hosts
or CIDRs. Record values contain policy metadata such as:

```text
owner=NOC;service=WUG;ticket=CHG0123456;expires=2026-12-31
```

## D-02: Stable Enforcement, Mutable Policy

The iRule owns mechanics; the DG owns exceptions. Adding, changing, or deleting an
exception must not require an iRule edit or rule reload. The initial POC modifies only
the full rule. The lite variant is intentionally left unchanged until its owner agrees
to consume the canonical policy.

## D-03: Trusted Means Rate-Limit Bypass Only

A trusted source bypasses request-rate accounting and active rate-limit blocks. TLS
enforcement, XFF sanitation, prompt-injection inspection, response hardening, and ISA
logging remain active. Trust is not a blanket WAF bypass.

## D-04: Optional Policy Fails Closed

The DG name is held in a variable to avoid BIG-IP link-time validation. `RULE_INIT`
checks availability once. If the DG is missing, SwagWAF logs the condition and applies
normal rate limiting to every source.

## D-05: Metadata Is Audit Evidence

The matched DG record and sanitized record value are included in every
`SWAGWAF|TRUSTED_SOURCE` event. User-controlled metadata may not inject pipe delimiters,
quotes, or newlines into structured logs.

## D-06: Block Lifetime Must Not Be Client-Renewable

`table lookup -notouch` is required for `block:<ip>` checks. A normal lookup touches the
entry and can perpetually renew its idle timeout when a monitor retries continuously.

## D-07: Desired State Precedes Mutation

The future self-service workflow may accept intake from a form or Google Sheet, but the
approved desired state must live in Git or an authoritative ServiceNow table. Deployment
should reconcile the complete canonical DG. Incremental tmsh record mutations remain a
break-glass or implementation detail, not the authoritative state model.

## D-08: Repository-Local Handoff Without AGENTS.md

SwagWAF uses `.HANDOFF/` as its self-contained context boundary and intentionally does
not add a repo-local `AGENTS.md`. Workspace-level safety and file conventions are
inherited where available; project decisions and state remain portable in this repo.
