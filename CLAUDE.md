# D:\Gamedev — Project Instructions

## Start here
Read `phases/README.md` first: the 20-phase execution table, the supervised review loop rules, and every phase's status. The phase in progress has its own folder (`phases/PHASE_NN_<Name>/`) with PLAN, EXECUTION_LOG, FAILURE_POINTS, REVIEW, and LEDGER. `NEXT_SESSION.md` holds the original prompts and the session-to-session state.

## What this project is
A Godot 4.7.1 top-down 2D dual-entity survival roguelite: protect yourself and a central Tower at the same time. The Godot project skeleton exists (project.godot with the pinned settings, the 16 collision layers, the input map, a BootCheck autoload, and a Windows release export); no gameplay code exists yet.

## Source of truth
- `MASTER_SDLC.md` (v0.8.4) — intent, rules, gates, Acceptance Test Matrix, Development Phase Map for Phases 0–2 (including E0.1 and E0.2), Provisional Values Register, Review Decision Log.
- `docs/` — draft system documents: 09 Enemy AI, 11 Wave Director, 19 UI/UX, 20 Technical Architecture, 29 Milestones and Roadmap (Phases 3–4, Deferred Review Findings).
- The master wins on intent; the Provisional Values Register wins on any numeric conflict.

## Rules for any agent working here
- Every gameplay number lives in the Provisional Values Register; every other place references it. One carve-out, and only one (decision D91): a count the master itself states as **structure** rather than tuning — "four nested structures", "the four prototype encounter types", "exactly two boss-class encounters" — is not a gameplay number and needs no Register citation. A number that could be tuned without changing the shape of the game is a gameplay number and cites the Register, even when it looks structural. If a count is arguable, cite the Register.
- Every design change gets a Review Decision Log row naming the alternative. Decisions labelled "Author decision" were made by the author; change them only with the author's approval.
- Never write that a gate is passed, satisfied, or ready; reviewers and the author decide.
- Send genuine design contradictions or scope changes to the author as short multiple-choice questions.
- Sonnet subagents do bulk writing and implementation; Opus runs reviewers and critical agents.
- Before re-review, sweep changed files for superseded wording.
- Once the repository exists, commit documentation and implementation changes together.

## GodotPrompter
The `godot-prompter` plugin (v1.13.3) adds 55 Godot skills and 8 specialist agents.

- Before implementing any Godot system - controller, state machine, AI, UI, shader, test, export - check for a matching `godot-prompter:*` skill and invoke it first. This applies to subagents writing Godot code, which is most implementation work here.
- The skills advise on Godot idiom. They never override this project. Where a skill conflicts with `docs/20_Technical_Architecture.md`, the Provisional Values Register, or an Author decision, this project wins and the conflict is recorded in the phase LEDGER.
- This project targets **Godot 4.7.1**. If any tool or skill reports 4.4, it has misread a stray `project.godot`; the pinned version is in the Provisional Values Register (Engine & Platform).
- The pack's generic `godot-project-setup` suggests autoloads (GameManager, AudioManager, SaveManager) this project does not use. The autoloads are defined by docs/20: SimClock, PauseAuthority, EventBus, EntityRegistry.

## Tools
- Godot 4.7.1 at `D:\godot`.
- Godot MCP servers `godot-comprehensive` and `godot-coding-solo` are configured for this project and allowed in `.claude/settings.json`; file deletion and project export still ask; Docker export, CI pipeline, HTTP request, WebSocket and multiplayer server creation are denied outright. Note that the ask gate does NOT intercept subagents (Phase 00 finding F-06), so every delegation prompt must carry the sandbox-only and no-delete/no-export constraints explicitly. Both are pinned to exact commits and run from locally built copies under `tools/mcp/` (gitignored), because npx on this machine cannot install commit-pinned git specs. The commits and the rebuild steps are recorded in docs/28.
- `godot-comprehensive`’s `run_project` and every `game_*` tool are sandbox-only (author decision): `run_project` injects an autoload into `project.godot` and opens a local listener exposing arbitrary GDScript. Its authoring tools do not inject and stay available for the real project.
- Godot skill pack: `godot-prompter` 1.13.3 (MIT), installed from the `godot-prompter-marketplace` marketplace, project-scoped to this project. See the GodotPrompter section above.
