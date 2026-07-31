# Lightbulb Log

```
# --------------------------------------------------------------------------
# NOTES:    LIGHTBULB-LOG.md
# --------------------------------------------------------------------------
# ABSTRACT: Append-only failure archive for durable SwagWAF process lessons.
# CREATED:  260731 BY: Sol(GPT5.6)::Copilot:MAC-00
# UPDATED:  260731 BY: Sol(GPT5.6)::Copilot:MAC-00
# VERSION:  0.1.0
# ARCHITECT: JN
# TECHLEAD: JN
# STAGE:    ACTIVE
# --------------------------------------------------------------------------
```

- FAIL #1 — Uncommitted phase transitions turned release closeout into forensic recovery
  When:   2026-07-31
  What:   Continued from validated implementation into release manipulation, QA follow-up, and handoff work without first preserving each coherent phase as a durable commit.
  Cost:   Repeated test/approve/rework cycles, avoidable rollback and recovery work, a full Git/transcript/snapshot forensic audit, excess terminal use, and reduced confidence that all work survived.
  Why:    The workflow treated additional review cycles and stopping with uncertainty as the only choices. It lacked mandatory commit checkpoints that separated validated implementation, release packaging, post-QA hardening, and handoff bookkeeping.
  LESSON: After one focused validation passes, commit the coherent change immediately and record what is validated versus pending. Never begin release, QA follow-up, branch/tag manipulation, or handoff work while the preceding phase exists only in the working tree or chat transcript.