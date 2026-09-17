# Next Session — Start Here

**State on 2026-09-17**
- Prompt 1 has been run: the work is split into 20 execution phases, the author approved the split, and `phases/` now holds the phase table, the loop rules, and a folder per phase. Phase 00 (Environment & Connection) is the phase in progress; it runs Prompt 2 as task E0.1 and Prompt 3 as task E0.2, both now rows in the master's Development Phase Map (decision D77).

**State on 2026-09-14**
- Design is complete for prototype work: `MASTER_SDLC.md` v0.8.1 plus draft system documents in `docs/` (09 Enemy AI, 11 Wave Director, 19 UI/UX, 20 Technical Architecture, 29 Milestones and Roadmap with Deferred Review Findings).
- Last independent review: gameplay 4/10, technical 4/10, intent 7/10; a final consistency pass was lint-checked only. The author accepted this and expects the remaining polish to happen during implementation.
- The old master backups (v0.5.0 original, v0.6.x, v0.7.0) were deleted at the author's request. The Review Decision Log still quotes every 0.5.0 sentence it changed.
- No git repository and no Godot project exist yet.
- Godot 4.7.1 is installed at `D:\godot`. Two Godot MCP servers are configured for this project (unpinned). No Godot skills are installed.

## Next steps, in order
1. **Phase split and supervised execution loop** — run Prompt 1. It produces the phase plan and the `phases/` documents, then runs Phase 0.
2. **Godot ↔ agent connection test and project creation** — Prompt 2, executed as part of Phase 0.
3. **Godot skill installation** — Prompt 3, executed as part of Phase 0 once the sandbox from Prompt 2 exists.

Paste the prompts below one at a time, or tell the agent "run NEXT_SESSION.md Prompt 1".

---

## Prompt 1 — Phase split and supervised execution loop

```text
Act as the supervising orchestrator for building this game from its plan.

Read first: D:\Gamedev\CLAUDE.md; then D:\Gamedev\MASTER_SDLC.md (Development Readiness Threshold, Minimum Playable Prototype Gate, Acceptance Test Matrix, Development Phase Map, Provisional Values Register, Review Decision Log); then D:\Gamedev\docs\*.md, especially docs/29 for Phases 3–4 and Deferred Review Findings.

GOAL
Divide all the work in the plan into execution phases that can each be completed and verified on their own, then run the phases one at a time through a supervised review loop.

1. PHASE SPLIT
- Start from this draft of phases 0–8 and check it against the plan's task IDs, dependencies, and gates. Merge or split phases until each has one clear outcome, fits in a few sessions, and ends at a checkable gate. The final count may be more or fewer than nine; record the reason for every change.
  Draft to check:
  0 Environment — Godot–agent connection test in a sandbox, Godot skill installation, then the real project and repository
  1 Foundations — P0.1–P0.7
  2 Technical foundations — P1.1–P1.7
  3 Core prototype build — P2.1–P2.7, ending with the feel check
  4 Wave Director, pickups, upgrades, menus — P2.8–P2.14
  5 Prototype validation and gate — P2.15–P2.18
  6 Vertical slice systems — P3.1–P3.9 and P3.2b
  7 Vertical slice content, art, and playtest — P3.10–P3.18
  8 Production milestones — M4.1–M4.7 and P4.0
- Every plan task ID belongs to exactly one phase. List any task that fits nowhere and why.
- Show me the phase table before executing Phase 0.

2. PHASE DOCUMENTS — create D:\Gamedev\phases\
- phases\README.md — phase table (number, name, outcome, task IDs, dependencies, gate, status) and the loop rules below.
- phases\LESSONS.md — patterns carried between phases (starts empty).
- phases\PHASE_N_<Name>\ for every phase, containing:
  - PLAN.md — goal; entry conditions; tasks mapped to plan IDs; step-by-step implementation for each task; exit criteria and acceptance tests taken from the Acceptance Test Matrix, fixed before work starts; predetermined failure points and risks with mitigations; which agent does what.
  - EXECUTION_LOG.md — dated record of every action, command, file change, test run, and result.
  - FAILURE_POINTS.md — "Predetermined" (from PLAN.md) and "Discovered during execution" (what happened, cause, fix, how to prevent it next time).
  - REVIEW.md — every review iteration: per-task scores, phase execution score, findings, and the reasons behind any low score.
  - LEDGER.md — every finding with status (open, fixed, deferred with owner, withdrawn), carried across iterations.

3. LOOP FOR EVERY PHASE
a. Pre-implementation: read all earlier phases' EXECUTION_LOG, FAILURE_POINTS, REVIEW, and LESSONS. Write the patterns that apply to this phase into its PLAN.md (recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved).
b. Implementation: execute PLAN.md step by step. Log everything in EXECUTION_LOG.md and add each new failure point the moment it appears. The documents never claim the phase is complete; the reviewers decide.
c. Review gate — execution stops here until the review returns:
   - Critical agents, one per task in the phase: check that task against its plan steps and acceptance tests using real evidence (files, test output, logs, screenshots) and score it out of 10.
   - Phase reviewer, one agent for the phase as a whole: score execution out of 10 against PLAN.md and the master plan and, if the score is low, explain why.
   - Reviewers never see the implementer's reasoning. They receive PLAN.md, LEDGER.md, and the artifacts, and they mark every ledger item closed, not closed, or regressed before raising new findings. New findings count only if they are contradictions or problems that block this phase's exit criteria.
d. Fix and repeat: gather all feedback into LEDGER.md, fix, and review again until the phase meets its bar — phase score at least 8/10, every task at least 7/10, no open Blocker or Major, every exit test passing. Before each re-review, sweep all changed files for superseded wording. If three review iterations fail to reach the bar, stop and bring me the ledger summary and your diagnosis instead of looping further.
e. Close: update LESSONS.md and the README status; update the affected master and docs sections (numbers only in the Provisional Values Register; every design change gets a Review Decision Log row); add a Change Log row. Then start the next phase.

WORKING RULES
- Sonnet subagents write code and documents; Opus runs the critical agents and phase reviewers.
- Keep every rule and number in exactly one place.
- Send genuine design contradictions or scope changes to me as short multiple-choice questions; never resolve them silently.
- Once the repository exists, commit documentation and implementation changes together.
- Phase 0 runs Prompt 2 (connection test and project creation) and then Prompt 3 (skills) from D:\Gamedev\NEXT_SESSION.md.
```

---

## Prompt 2 — Godot ↔ agent connection test and project creation

```text
Prove a reliable local connection between Claude Code (including its subagents) and Godot 4.7.1 on this machine, then create the Godot project and control it end to end.

CONTEXT
- Godot 4.7.1: D:\godot\Godot_v4.7.1-stable_win64.exe, with the console build beside it.
- MCP servers configured for D:/Gamedev in local scope: godot-comprehensive (github:tugcantopaloglu/godot-mcp) and godot-coding-solo (@coding-solo/godot-mcp@latest), both with GODOT_PATH set, plus a filesystem MCP. Their tools are allowed in D:\Gamedev\.claude\settings.json; deletes, exports, and network calls still ask. Neither server version is pinned.

STEPS
1. Research first and write a short comparison of the ways agents control Godot:
   - MCP servers that drive Godot through its command line
   - MCP servers or editor plugins that open a local TCP or WebSocket bridge into the running editor and game
   - Godot's built-in ports: GDScript language server (default 6005), Debug Adapter Protocol (default 6006), remote debugger (default 6007)
   - headless command-line runs (--headless, --script, --export-release)
   - any newer approach you find
   Compare capabilities (edit scenes, run the game, read output, inspect the live scene tree, change properties, take screenshots, send input), reliability on Windows, and security (localhost only).
2. Create a sandbox at D:\Gamedev\sandbox\connection_test, separate from the real project, and run this connection test matrix with every viable method. Record pass or fail with evidence for each item:
   - read the Godot version
   - create a project, a scene, and nodes; save them and read them back
   - create, attach, and validate a GDScript
   - run the project, capture debug output, stop it
   - inspect the running game's scene tree, change a property live, take a screenshot, inject input
   - run a headless script and read its exit code
   - failure behaviour and recovery: Godot not running, port already in use, editor closed mid-command
   - whether Sonnet and Opus subagents can call the same tools
   - rough latency per call
   Install a bridge addon that a server needs only after reading its code, and only into the sandbox first.
3. Choose a primary method and a fallback. Pin both MCP servers to exact versions (task P0.5). Record known failure points and workarounds.
4. Document everything in the Phase 0 folder (PLAN, EXECUTION_LOG, FAILURE_POINTS) and in docs/28 under "Godot Connection".
5. Only after the connection is proven, create the real project exactly as task P0.2 specifies (pinned settings, the 16 collision layer names, input map, folder layout, 4.7.1 export templates) and control it through the chosen method. Initialise git first (task P0.1) if the phase plan orders it that way.

Stop and ask me before opening any port beyond localhost, installing software outside the project, or deleting files.
```

---

## Prompt 3 — Godot skill installation

```text
Install Godot skills for Claude Code in this project, safely.

CONTEXT
No Godot skills are installed. Candidates found on 2026-09-14:
- Randroids-Dojo/Godot-Claude-Skills — Godot 4.x development, GdUnit4 tests, PlayGodot automation. Installed with: /plugin marketplace add Randroids-Dojo/Godot-Claude-Skills, then /plugin install godot
- alexmeckes/godot-claude-skills — GDScript patterns and live editor sessions.
Search for newer or better-maintained options too.

STEPS
1. Compare the candidates: contents (SKILL.md files, scripts, hooks, any MCP servers they add), maintenance activity, license, Godot 4.7 compatibility, and overlap with the Godot connection method chosen in Prompt 2.
2. Security review before installing: read every script and hook. Reject anything that makes unexplained network calls, reads credentials, or writes outside the project.
3. Pick one primary skill, plus a second only if it adds something distinct. Plugin marketplace commands are typed by me, so give me the exact commands to run. If a skill is a plain folder, copy it into D:\Gamedev\.claude\skills after review.
4. Verify: after a restart the skill appears in the skill list, and it works once on the sandbox project from Prompt 2 (D:\Gamedev\sandbox\connection_test).
5. Check fit with the plan: GdUnit4 matches task P0.7's test harness; note any conflict with the master's Godot standards.
6. Record the choice, versions, and verification results in docs/28 (AI Development Workflow) and in Phase 0's EXECUTION_LOG.md.
```
