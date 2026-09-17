# D:\Gamedev — Project Instructions

## Start here
Read `phases/README.md` first: the 20-phase execution table, the supervised review loop rules, and every phase's status. The phase in progress has its own folder (`phases/PHASE_NN_<Name>/`) with PLAN, EXECUTION_LOG, FAILURE_POINTS, REVIEW, and LEDGER. `NEXT_SESSION.md` holds the original prompts and the session-to-session state.

## What this project is
A Godot 4.7.1 top-down 2D dual-entity survival roguelite: protect yourself and a central Tower at the same time. No code or Godot project exists yet; the design is ready for prototype work.

## Source of truth
- `MASTER_SDLC.md` (v0.8.1) — intent, rules, gates, Acceptance Test Matrix, Development Phase Map for Phases 0–2 (including E0.1 and E0.2), Provisional Values Register, Review Decision Log.
- `docs/` — draft system documents: 09 Enemy AI, 11 Wave Director, 19 UI/UX, 20 Technical Architecture, 29 Milestones and Roadmap (Phases 3–4, Deferred Review Findings).
- The master wins on intent; the Provisional Values Register wins on any numeric conflict.

## Rules for any agent working here
- Every gameplay number lives in the Provisional Values Register; every other place references it.
- Every design change gets a Review Decision Log row naming the alternative. Decisions labelled "Author decision" were made by the author; change them only with the author's approval.
- Never write that a gate is passed, satisfied, or ready; reviewers and the author decide.
- Send genuine design contradictions or scope changes to the author as short multiple-choice questions.
- Sonnet subagents do bulk writing and implementation; Opus runs reviewers and critical agents.
- Before re-review, sweep changed files for superseded wording.
- Once the repository exists, commit documentation and implementation changes together.

## Tools
- Godot 4.7.1 at `D:\godot`.
- Godot MCP servers `godot-comprehensive` and `godot-coding-solo` are configured for this project and allowed in `.claude/settings.json`; deletes, exports, and network calls still ask. Both are pinned to exact commits and run from locally built copies under `tools/mcp/` (gitignored), because npx on this machine cannot install commit-pinned git specs. The commits and the rebuild steps are recorded in docs/28.
- `godot-comprehensive`’s `run_project` and every `game_*` tool are sandbox-only (author decision): `run_project` injects an autoload into `project.godot` and opens a local listener exposing arbitrary GDScript. Its authoring tools do not inject and stay available for the real project.
- No Godot skills are installed yet.
