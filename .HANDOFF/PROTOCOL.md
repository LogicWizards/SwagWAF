Read [](file:///Users/jnegron9/DATA/projects/ai-labs)

Read [](file:///Users/jnegron9/DATA/projects/ai-labs/.HANDOFF)

Read [](file:///Users/jnegron9/DATA/projects/ai-labs/.HANDOFF/.PROTOCOL)

Read [](file:///Users/jnegron9/DATA/projects/ai-labs/.HANDOFF/.PROTOCOL/5-star-thumbprint.md#1-1), lines 1 to 200

Read [](file:///Users/jnegron9/DATA/projects/ai-labs/.HANDOFF/.PROTOCOL/decision-matrix.md#1-1), lines 1 to 100

Read [](file:///Users/jnegron9/DATA/projects/ai-labs/MULTI-AGENT-COORDINATION-RESEARCH.md#1-1), lines 1 to 60

Here's the full picture:

---

## The 5-Star Thumbprint Protocol

Developed in ai-labs, codified in `.HANDOFF/.PROTOCOL/5-star-thumbprint.md`. It's a **context continuity standard** for AI-assisted development across sessions, tools, and agents.

### The 5 Stars

| Star | File | Coverage |
|---|---|---|
| ★1 | AGENTS.md at repo root | Claude Code, Gemini CLI, VS Code Copilot, Codex |
| ★2 | `HANDOFF.instructions.md` (applyTo: \*\*) | VS Code Copilot — auto-injected every session |
| ★3 | `.github/instructions/*.instructions.md` | Domain-specific IDE rules |
| ★4 | `.HANDOFF/` — 4 files: FEATURE, SPEC, DESIGN, STATE | All tools — loaded at session start |
| ★5 | `.HANDOFF/SESSIONS/` — per-session, then immutable | All tools — loaded on demand |

### The 5-Way `.HANDOFF/` Split

Each file has a different change cadence, which is why they're split:

- **PROTOCOL.md** — (THIS FILE) - updated from ai-labs.org
- **FEATURE.md** — written once at epic start, never edited (scope anchor)
- **SPEC.md** — updated at sprint boundaries only (acceptance criteria)
- **DESIGN.md** — append-only on architecture decisions (regression prevention)
- **STATE.md** — updated every session (live task board, blockers with `done-when` conditions)

STATE.md stays under ~50 lines of live content. Completed work moves to a SESSION.md, not piles up in STATE.

### Session Format — SBAR

Each `SESSIONS/YYMMDD-<slug>/SESSION.md` follows clinical handoff format (SBAR):
- **S**ituation — current state, phase, blockers
- **B**ackground — why the project exists, key constraints
- **A**ssessment — what was found/decided/produced this session
- **R**ecommendation — what happens next, in order

### Stale Handoff Signal

If an AI says **"Now I can see the full picture"** — stop. That phrase signals the handoff failed. Update the relevant `.HANDOFF/` docs before continuing. (This is also in your user memory.)

### Handback / Swarm Pattern (research-stage)

The multi-agent coordination research captured in MULTI-AGENT-COORDINATION-RESEARCH.md extends the protocol to parallel agents:
- Each agent gets a scoped task file with acceptance criteria and dependencies
- Agents write progress to a shared state file
- User merges completed work (git-style)
- Currently at "staggered sequential" MVP — true parallel swarm is still a research item

### Minimum Viable Thumbprint (two files)

```
AGENTS.md
.HANDOFF/STATE.md
```
This is the floor. Anything less = cold-transfer repo.

---

SwagWAF is running the full 5-star (AGENTS.md + .HANDOFF/STATE.md + SESSIONS/ already in place). The FEATURE/SPEC/DESIGN split could be added later if the project grows.