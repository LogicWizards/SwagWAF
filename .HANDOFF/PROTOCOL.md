# Protocol: SwagWAF Context Continuity

```
# --------------------------------------------------------------------------
# CONFIG:   PROTOCOL.md
# --------------------------------------------------------------------------
# ABSTRACT: Project-local 5-Star handoff rules for SwagWAF, version-pinned
#     to the upstream protocol with documented local adaptations.
# CREATED:  260518 BY: JN
# UPDATED:  260730 BY: JN
# VERSION:  0.3.8
# ARCHITECT: JN
# TECHLEAD: JN
# --------------------------------------------------------------------------
```

## Upstream

SwagWAF follows the 5-Star HANDOFF Protocol v0.5 maintained by `wwwizards/ai-labs`.
This file is the portable project summary; a cold-starting contributor must not require
access to the upstream private working tree.

## Project Context

Read these files at the start of substantive work:

| File | Purpose | Update cadence |
|---|---|---|
| `FEATURE.md` | Immutable project intent and boundaries | Write once |
| `SPEC.md` | Current acceptance criteria | Phase boundaries |
| `DESIGN.md` | Append-only architectural decisions | Decision changes |
| `ROADMAP.md` | Sequenced future delivery | Material reprioritization |
| `STATE.md` | Current branch, version, blockers, and next actions | Every handoff |
| `SESSIONS/*/README.md` | Immutable SBAR evidence | Once per session |

## Local Adaptations

1. No repo-local `AGENTS.md` is maintained. Project truth lives in `.HANDOFF/`; workspace
   safety and file conventions are inherited when available.
2. `ROADMAP.md` is an additional permanent context file because policy automation spans
   multiple releases and ownership boundaries.
3. The existing flat `STATE.md` path is retained to avoid a migration during active QA.
4. Session records use `SESSIONS/YYMMDD-<slug>/README.md` for GitHub preview.

## Rules

- Do not state assumptions as facts; preserve command output or logs as evidence.
- Validate BIG-IP CLI syntax on the target TMOS version or against official F5 references.
- Do not invent tmsh modules for generic iRule `table` state.
- Do not edit immutable closed session records; correct current truth in `STATE.md` and
  append a new session record explaining the delta.
- Architectural reversals require a new decision in `DESIGN.md`; never silently delete
  the decision being superseded.
- Keep secrets out of chat, Git, data-group metadata, logs, and command arguments.

## SBAR

Each session record contains Situation, Background, Assessment, and Recommendation,
followed by artifacts, decisions, validation evidence, and lessons when applicable.

## Stale-Handoff Signal

If an agent says "Now I can see the full picture" or an equivalent phrase, stop work,
identify what the handoff omitted or contradicted, update the relevant `.HANDOFF/`
documents, and produce a corrected handoff before continuing.
