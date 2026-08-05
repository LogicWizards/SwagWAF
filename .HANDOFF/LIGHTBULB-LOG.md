# Lightbulb Log

```
# --------------------------------------------------------------------------
# NOTES:    LIGHTBULB-LOG.md
# --------------------------------------------------------------------------
# ABSTRACT: Append-only failure archive for durable SwagWAF process lessons.
# CREATED:  260731 BY: Sol(GPT5.6)::Copilot:MAC-00
# UPDATED:  260805 BY: Sol(Opus4.8)::Copilot:MAC-00
# VERSION:  0.1.1
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

- FAIL #2 — Session shipped commits but produced no immutable SESSION SBAR
  When:   2026-08-04 (caught 2026-08-05)
  What:   The v0.3.8.1 session landed commits ed96ca5 and 27f33ef and updated STATE.md, but never created the required SESSIONS/YYMMDD-<slug>/README.md SBAR. The operator noticed the missing session record (and asked about a TESTING.md) the next day.
  Cost:   Lost immutable evidence for a full validate-and-ship session; the SBAR had to be reconstructed retroactively from the transcript; brief loss of confidence that the wrap process is reliable.
  Why:    PROTOCOL.md requires a SESSION record once per session, but nothing enforces it at wrap time. STATE.md updates were treated as the whole handoff, and rapid urgency redirects ("vacation", "just don't commit", "go for it") pulled focus away from the once-per-session artifact. Not an LLM-switch loss — the protocol lives in-repo.
  LESSON: If a session produced any commit, creating the SESSIONS/ SBAR is a required wrap step. Before saying "done"/"clean"/"enjoy your vacation", write and commit the SBAR. Updating STATE.md is not a substitute. TESTING.md is not a required artifact — testing docs live in tests/README.md and docs/testing-*.md.