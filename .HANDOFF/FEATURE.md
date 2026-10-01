# Feature: SwagWAF

```
# --------------------------------------------------------------------------
# NOTES:    FEATURE.md
# --------------------------------------------------------------------------
# ABSTRACT: Immutable scope anchor for SwagWAF, a BIG-IP iRule that provides
#     practical WAF controls for AI/API endpoints without requiring AWAF.
# CREATED:  260730 BY: JN
# UPDATED:  260730 BY: JN
# VERSION:  0.3.8
# ARCHITECT: JN
# TECHLEAD: JN
# --------------------------------------------------------------------------
```

## Intent

Provide a deployable, auditable BIG-IP LTM security layer for organizations that need
rate limiting, prompt-injection detection, TLS enforcement, and HTTP hardening without
an enterprise WAF license.

## Operating Model

- Network engineering owns stable iRule enforcement logic.
- ISA owns security visibility and policy review.
- Mutable exception and detection policy lives in canonical BIG-IP data groups.
- Application owners request policy changes through governed automation, not Tcl edits.
- The same policy objects are consumed by every supported SwagWAF rule variant.

## Scope

- BIG-IP v17.x-compatible iRules for AI/API and conventional HTTP applications.
- Structured `SWAGWAF|EVENT|key=value` events consumable by Sumo Logic.
- Optional data groups with safe fallback behavior when policy is absent.
- Git-backed examples and automation for policy deployment.

## Non-Goals

- Replacing BIG-IP AWAF, F5 Distributed Cloud WAAP, or inference-layer guardrails.
- Giving application owners direct BIG-IP access.
- Maintaining independent exception lists in each iRule variant.
- Treating a spreadsheet or intake form as authoritative desired state.
