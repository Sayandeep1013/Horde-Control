# Phase 00 - Environment & Connection

Status: Not started
Executes: MASTER_SDLC.md Development Phase Map Phase 0 (part)
Plan task IDs: P0.1, P0.3, E0.1, E0.2, P0.2, P0.5

This phase covers only P0.1, P0.3, E0.1, E0.2, P0.2, and P0.5. P0.4, P0.6, and P0.7 belong to a later phase (see `phases/README.md` phase table, phase 01); the master's own Phase 0 exit line ("P0.1 to P0.7 complete; Change Log row 'Phase 0 accepted'") is not reached by this phase alone and this plan does not claim it is.

## Goal

Reach the point where every later phase can trust the ground under it: a version-controlled repository containing the existing design documents and this phase's own planning documents; a connection between the AI collaborator (including its Sonnet and Opus subagents) and Godot 4.7.1 that has been proven in a throwaway sandbox rather than assumed; a Godot skill installation chosen only after its code has been read; a real Godot 4.7.1 project skeleton built through the proven connection with the pinned settings, collision layers, input map, folder layout, and export templates docs/20 and docs/19 require; and document 28 at 1.0.0 recording all of it, including both Godot MCP servers pinned to exact versions.

## Entry conditions

- No git repository exists at `D:\Gamedev` (confirmed: this session's environment reports "Is a git repository: false").
- No Godot project exists at `D:\Gamedev` (no `project.godot`).
- Godot 4.7.1 is installed at `D:\godot`, with both the windowed executable (`Godot_v4.7.1-stable_win64.exe`) and the console executable (`Godot_v4.7.1-stable_win64_console.exe`) present, per NEXT_SESSION.md Prompt 2 context and CLAUDE.md > Tools.
- Two Godot MCP servers, `godot-comprehensive` and `godot-coding-solo`, are configured for this project and allowed in `D:\Gamedev\.claude\settings.json`. As read at the start of this phase, that file's `permissions.allow` covers both server namespaces wholesale, and `permissions.ask` singles out `mcp__godot-comprehensive__delete_file`, `export_project`, `manage_docker_export`, `manage_ci_pipeline`, `game_http_request`, and `game_websocket` - i.e. deletes, exports, and network calls still ask, matching CLAUDE.md > Tools.
- Neither MCP server is pinned to an exact version (CLAUDE.md > Tools: "Their versions are not pinned yet"). Pinning both is P0.5's job in this phase.
- No Godot skills are installed in this project (CLAUDE.md > Tools).
- `phases/README.md` and `phases/LESSONS.md` already exist (written under NEXT_SESSION.md Prompt 1, before this plan). `phases/LESSONS.md` carries an empty table; no phase has produced a lesson yet.
- Entry condition to carry into E0.1: on 2026-09-17, the `filesystem` and `maestro` MCP servers each failed to connect after a 30 second timeout (`CONNECT_TIMEOUT`). NEXT_SESSION.md Prompt 2's context section lists "a filesystem MCP" among the servers configured for this project, alongside the two Godot MCP servers; CLAUDE.md > Tools does not mention a filesystem or maestro server at all. E0.1's research and matrix must record whether the filesystem server is needed for any connection-test item, and must not silently assume a capability that server would have provided.

## Carried lessons

None - this is the first phase. phases/LESSONS.md is empty.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P0.1 | Put the project under version control | Repository at `D:\Gamedev` with one commit | none (Build-Ready 3 becomes enforceable) | `git log` shows the 0.8.1 commit | 28 | S | Sonnet implements; Opus critical agent checks at the review gate |
| P0.3 | Create the documentation skeleton | 26 new stub files; docs 09, 11, 19, 20, 29 gain stub header fields over their existing content | none formal | Every register entry's owner file exists | 28 | S | Sonnet implements; Opus critical agent checks at the review gate |
| E0.1 | Prove and choose the agent-to-Godot control path | The "Godot Connection" section of docs/28 with matrix results and evidence, plus the sandbox | none formal; every matrix row records pass or fail with evidence | Every matrix row has a recorded result, and a primary method and a fallback are named with their known failure modes | 28 | S | Sonnet researches and runs the matrix; Opus critical agent checks at the review gate |
| E0.2 | Install and verify Godot skills for Claude Code | Installed skills recorded in docs/28 with versions and verification results | none formal; verification is one successful use against the E0.1 sandbox | The chosen skill appears in the skill list after a restart and completes one task against the sandbox, and the security read is recorded | 28 | S | Sonnet researches, security-reads, and verifies; Opus critical agent checks at the review gate |
| P0.2 | Create the Godot 4.7.1 project skeleton | Empty project that opens without errors and exports a release build | Settings check (P0.2) | Project opens; layer names match the binding table; project.godot records engine version 4.7 while the boot check confirms 4.7.1; empty scene exports to a Windows release build | 20 (consults 23) | S | Sonnet implements; Opus critical agent checks at the review gate |
| P0.5 | Write document 28 (AI workflow) to 1.0.0 | docs/28 at 1.0.0, pinning both Godot MCP server versions | none formal | Every rule in it is enforceable with the tools present; doc lint: zero placeholders; every Owns entry has a resolved or accepted row; committed | 28 | S | Sonnet writes; Opus critical agent checks at the review gate |

One Opus phase reviewer additionally scores the phase as a whole at the review gate (see "Agent assignment").

A naming note carried into every step below: the master and NEXT_SESSION.md refer to document 28 throughout as "docs/28" or "docs/28.md". The existing docs (09, 11, 19, 20, 29) follow the pattern `NN_Title_With_Underscores.md`; under that same pattern document 28's file is `docs/28_AI_Development_Workflow.md`. Every instruction below that says "docs/28" means that file.

## Step-by-step implementation

### P0.1 - git init, .gitignore, first commit

1. Confirm the entry condition: no `.git` directory exists at `D:\Gamedev`.
2. Run `git init` at `D:\Gamedev`.
3. Create `D:\Gamedev\.gitignore` with at least these entries, each with a short comment:
   - `.godot/` - Godot's local editor cache, regenerated per machine.
   - `.import/` - legacy import cache (pre-4.x layout; harmless to exclude even if unused under 4.7).
   - `export_presets.cfg` - NO LONGER EXCLUDED. Reversed at P0.2 and recorded as decision D80: P4.5.3 requires two consecutive byte-identical exports from the same commit, which is not reproducible while the preset is untracked, and the preset carries no secrets today. If signing is ever added, the keystore path and password go in environment variables, never in this file.
   - `*.translation` - compiled translation binaries generated from source `.csv`/`.po` files.
   - Build output: `builds/`, `export/`, `*.pck`, `*.exe`, `*.exp`, `*.lib`, `*.pdb` - the release export artifacts P0.2 produces are not committed.
   - `sandbox/` - the entire E0.1/E0.2 sandbox tree (`D:\Gamedev\sandbox\connection_test` and anything else under `sandbox/`) is throwaway test scaffolding and must not enter the repository.
4. Stage exactly: `MASTER_SDLC.md`, `docs/` (as it exists at this point in execution - the five drafted documents 09, 11, 19, 20, 29; P0.3 has not run yet), `CLAUDE.md`, `NEXT_SESSION.md`, and `phases/` (including this plan and its sibling PHASE_00 files, plus `phases/README.md` and `phases/LESSONS.md`).
5. Do not stage `.claude/` unless the author confirms it should be versioned; it is not named in the master's P0.1 scope.
6. Commit with this message format:
   - Subject line: `P0.1: initialize repository (<version>)`, where `<version>` is MASTER_SDLC.md's version header as read at commit time, not a hardcoded value. Read the header at commit time rather than assuming 0.8.0, per the instruction that "the master's first-commit version wording is whatever version the master carries at commit time"; as of 2026-09-17 the master carries 0.8.1 (the execution-mapping pass that added E0.1 and E0.2), so 0.8.1 is expected but must be verified, not assumed.
   - Body: one or two sentences naming the files committed (MASTER_SDLC.md, docs/, CLAUDE.md, NEXT_SESSION.md, phases/) and citing task P0.1.
   - Footer: whatever attribution the active session's instructions require at commit time.
7. Exit check: run `git log` and confirm it shows this commit (subject line visible, files listed via `git show --stat`).

### P0.3 - documentation skeleton (26 stubs + 5 header upgrades)

1. Read MASTER_SDLC.md's "Documentation Structure" section in full (headings "## 00 - ..." through "## 30 - ..."). For every document, copy its heading title, its remit paragraph(s) (the "Answers:" sentence where present), and its "Owns:" list verbatim where one is present. Where a document has no "Owns:" list in that section (for example 00, 01, 23, and others), do not invent one; the stub records "Owns: none listed in Documentation Structure."
2. The 26 documents that do not exist yet (00-30 minus the five drafts 09, 11, 19, 20, 29) are, using the existing `NN_Title_With_Underscores.md` naming pattern (ampersands become "and", slashes are dropped, parentheticals are dropped, matching how `19_UI_UX.md`, `20_Technical_Architecture.md`, and `29_Milestones_and_Roadmap.md` were already named):
   `00_Vision_and_Design_Philosophy.md`, `01_Design_Pillars.md`, `02_Gameplay_Loop.md`, `03_Player_Controller_Specification.md`, `04_Grappling_System.md`, `05_Combat_System.md`, `06_Weapon_Framework.md`, `07_Tower_System.md`, `08_Factory_System.md`, `10_Boss_Design.md`, `12_Difficulty_Scaling.md`, `13_Roguelite_Progression.md`, `14_Economy.md`, `15_Biomes.md`, `16_Resource_System.md`, `17_Upgrade_Pools.md`, `18_Permanent_Skill_Tree.md`, `21_Scene_Tree.md`, `22_Node_Hierarchy.md`, `23_Folder_Structure.md`, `24_Save_System.md`, `25_Asset_Pipeline.md`, `26_Audio_Design.md`, `27_VFX_and_Game_Feel.md`, `28_AI_Development_Workflow.md`, `30_Future_Ideas.md`. That is 26 files.
3. Each of the 26 stub files gets this header, in order: title (`# NN - <Title>`), `**Version:** 0.1.0`, `**Status:** Stub - not yet a working document`, a remit paragraph copied from step 1, and an `Owns:` list copied from step 1 (or the "none listed" line).
4. Documents 09, 11, 19, 20, and 29 keep every sentence of their existing content unchanged and gain the same fields used in step 3 - remit paragraph and `Owns:` list, copied from the Documentation Structure section - inserted near their existing header. Do not change their existing `**Version:**` line; they keep whatever version they already carry (for example docs/20 is at 0.2.0), since the master's P0.3 wording says these five documents "keep their content and gain the same stub header fields," not that their version resets to 0.1.0.
5. Exit check: for every entry in MASTER_SDLC.md's edge-case register (the "If a system document changes one of these defaults..." table and any other register table naming an owning document), confirm the cited owning document's file now exists under `docs/`.

### E0.1 - prove and choose the agent-to-Godot control path

1. Research step first, written up before any sandbox work: compare, for Godot 4.7.1 on Windows, at least these control methods on capability (edit scenes, run the game, read output, inspect the live scene tree, change properties, take screenshots, send input), Windows reliability, and localhost-only security:
   - MCP servers that drive Godot through its command line (`godot-comprehensive`, `godot-coding-solo`, and any newer equivalent found).
   - MCP servers or editor plugins that open a local TCP or WebSocket bridge into the running editor and game.
   - Godot's built-in ports: GDScript language server (default 6005), Debug Adapter Protocol (default 6006), remote debugger (default 6007).
   - Headless command-line runs (`--headless`, `--script`, `--export-release`).
   - Any newer approach found during research.
2. Create the sandbox at `D:\Gamedev\sandbox\connection_test`, kept separate from the real project (which does not exist yet at this point in execution order - P0.2 runs after E0.1 and E0.2).
3. Build the connection test matrix as a checklist, one row per item, run with every viable method from step 1:
   - Read the Godot version.
   - Create a project, a scene, and nodes; save them and read them back.
   - Create, attach, and validate a GDScript.
   - Run the project, capture debug output, stop it.
   - Inspect the running game's scene tree, change a property live, take a screenshot, inject input.
   - Run a headless script and read its exit code.
   - Failure behaviour and recovery: Godot not running, port already in use, editor closed mid-command.
   - Whether Sonnet and Opus subagents can call the same tools.
   - Rough latency per call.
   Record pass or fail with evidence (file paths, log excerpts, screenshot paths) for every row, for every method tried.
4. Bridge addon rule: if a method under test needs a bridge addon, read its code first, and install it only into the sandbox, never into a real project, until it has been chosen.
5. Stop rule: stop and ask the author before opening any port beyond localhost, installing software outside the project, or deleting files. This applies for the whole of E0.1 and E0.2.
6. While running the matrix, also resolve the entry condition carried from above: does any matrix row actually require the `filesystem` MCP server (which failed to connect on 2026-09-17), or can every row be completed through the Godot MCP servers and direct file tools alone? Record the answer; do not assume the filesystem server is required or unneeded without testing.
7. From the completed matrix, choose one primary method and one fallback method. Record each one's known failure modes and workarounds.
8. Write the results (matrix, evidence, chosen methods, failure modes) into the "Godot Connection" section of `docs/28_AI_Development_Workflow.md` (created as a stub by P0.3, immediately before this task in execution order).

### E0.2 - Godot skills for Claude Code

1. Compare candidate skill packages: Randroids-Dojo/Godot-Claude-Skills (marketplace commands: `/plugin marketplace add Randroids-Dojo/Godot-Claude-Skills`, then `/plugin install godot`) and alexmeckes/godot-claude-skills (known candidates as of 2026-09-14 per NEXT_SESSION.md Prompt 3), plus a search for newer or better-maintained options.
2. For every candidate, inventory its SKILL.md files, scripts, hooks, and any MCP servers it would add; check maintenance activity, license, and Godot 4.7 compatibility; check overlap or conflict with the connection method E0.1 chose.
3. Security review before installing anything: read every script and every hook in full. Reject any candidate that makes an unexplained network call, reads credentials, or writes outside the project.
4. Choose one primary skill, and at most one complementary skill that adds something the primary does not cover.
5. Marketplace commands are typed by the author only - this plan produces the exact command text for the author to run (for example the two commands in step 1, if that candidate is chosen), and does not run them itself.
6. If the chosen skill (or complementary skill) is a plain folder rather than a marketplace package, copy it into `D:\Gamedev\.claude\skills` only after the security review in step 3 is complete and recorded.
7. After a restart, verify the skill appears in the skill list.
8. Verify the skill works by completing one task against the E0.1 sandbox at `D:\Gamedev\sandbox\connection_test`.
9. Check fit against task P0.7 (the gdUnit4 test harness, in a later phase): does the chosen skill assume or configure gdUnit4 compatibly, and does anything it does conflict with docs/20's Godot 4.x Implementation Standards? Record any conflict found; do not resolve a design conflict silently.
10. Record the comparison, the security-read result, the chosen skill(s) with exact versions, and the verification result in `docs/28_AI_Development_Workflow.md` and in this phase's `EXECUTION_LOG.md`.

### P0.2 - Godot 4.7.1 project skeleton

1. Confirm E0.1's exit criterion is met (a primary method and fallback are named with known failure modes) before starting; create the real project only through the chosen method, per E0.1's scope note that P0.2 additionally depends on E0.1.
2. Create the Godot 4.7.1 project at `D:\Gamedev` (the real project root, not the sandbox) through the chosen primary method.
3. Pin the project settings docs/20 > "Project Settings (pinned)" names - viewport, stretch mode and aspect, physics ticks per second and max physics steps per frame, physics interpolation, V-Sync - by setting the `project.godot` keys that section cites (`display/window/size/viewport_width` and `viewport_height`, `display/window/stretch/mode` and `aspect`, `physics/common/...` ticks and max steps, physics interpolation, `display/window/vsync/vsync_mode`). Cite docs/20 > Project Settings (pinned) for the values themselves; do not restate the numbers here.
4. Apply the 16 collision layer names under `layer_names/2d_physics` exactly as docs/20 > "Collision Layers (binding, not an example)" tables them (layers 1-16, PlayerBody through PlayerCollector). Cite that table; do not re-key the names from memory.
5. Build the input map per docs/19 > "Input Map": Move, Draft cycle, Draft number keys (1/2/3), Confirm, Reroll, Console cycle, Console number keys (1-7), Console Cancel, Pause, with their listed keyboard/mouse/gamepad bindings. Cite docs/19 > Input Map for the exact bindings.
   Debug toggles (resolved 2026-09-17, decision D78): bind F1 to the debug overlay and F2 to pseudo-localization, keyboard only, with no gamepad binding, exactly as docs/19 > Input Map now records them. Bind no other debug key; the Settings check requires these two present in the exported build.
6. Folder layout: docs/20's own Godot 4.x Implementation Standards section does not contain a folder-layout list; P0.2's owner column reads "20 (consults 23)", but document 23 ("Folder Structure") is only a P0.3 stub (title, one-line remit, no content) at this point in the phase - nothing in the Development Phase Map appears to write doc 23's real content before P0.2 needs it. In the absence of that content, build the top-level layout from the folder paths already named as deliverables across the Development Phase Map (for example `src/data/`, `src/debug/`, `src/combat/`, `src/audio/`, `src/player/`, `src/camera/`, `src/director/`, `src/upgrade/`, `src/pickup/`, `data/weapons/`, `data/upgrades/`, `data/pickups/`, `scenes/`) as a minimal, consistent root: `src/`, `data/`, `scenes/`, `addons/`. Record this as a gap for doc 23 to describe once it has real content, not as a decision doc 23 already made.
7. Verify the 4.7.1 export templates are present before exporting: `%APPDATA%\Godot\export_templates\4.7.1.stable\version.txt` must read `4.7.1.stable`. They were found missing and installed on 2026-09-17 under the author's explicit authorisation (see the export-templates row in "Predetermined failure points and risks" and this phase's EXECUTION_LOG). If they are absent or report a different version at this point, stop and ask the author again rather than re-downloading unprompted.
8. Add a boot check (an autoload or a startup script) asserting `Engine.get_version_info()` reports 4.7.1, alongside `project.godot` itself recording engine version 4.7 only, per docs/20's Version standard.
9. Export an empty scene as a Windows release build, using the installed 4.7.1 templates.
10. Exit check: the project opens without errors; the 16 layer names match the binding table; `project.godot` records 4.7 while the boot check confirms 4.7.1; the empty-scene Windows release export exists on disk.

### P0.5 - document 28 (AI workflow) to 1.0.0

1. Confirm P0.1, P0.2, P0.3, E0.1, and E0.2 have all produced their deliverables before writing this task's content (P0.5 additionally depends on E0.1 and E0.2, on top of the master's P0.1/P0.2/P0.3 dependency, per this phase's task ordering).
2. Write `docs/28_AI_Development_Workflow.md` to version 1.0.0, covering:
   - How the AI collaborator uses the Godot MCP tools (drawing on docs/20 > "Editor control from the AI collaborator").
   - The pinned exact versions of both `godot-comprehensive` and `godot-coding-solo`.
   - Any installed skill(s) and their pinned versions (from E0.2).
   - The chosen primary connection method and its fallback, with their known failure modes (from E0.1's "Godot Connection" section, already drafted in this same file during E0.1).
   - The same-commit rule (documentation and implementation change together, once the repository exists).
   - The review cadence (the phase loop in `phases/README.md`: pre-implementation, implementation, review gate, fix and repeat, close).
   - The Gate Approval rule (MASTER_SDLC.md > Document Control > Gate Approval): only the designer's Change Log row records a gate as passed; this document does not write that row for itself.
3. Doc lint pass: zero placeholder markers left in the file.
4. Resolve or explicitly accept every "Owns:" entry the stub carried forward from P0.3.
5. Commit docs/28 together with any other file changed to reach 1.0.0, per the same-commit rule this document itself states.
6. Exit check: every rule stated in the document is enforceable with the tools actually present in this project at commit time; doc lint clean; every Owns entry resolved or accepted; committed.

## Exit criteria and acceptance tests

Required for this phase's exit (named exactly as the Acceptance Test Matrix and the task texts name them):

- Every row of E0.1's connection test matrix carries a recorded result (pass or fail) with evidence, and a primary method and a fallback are named with their known failure modes (E0.1 exit criterion).
- `git log` shows the commit described in P0.1 (repository initialized; first commit containing MASTER_SDLC.md, docs/, CLAUDE.md, NEXT_SESSION.md, phases/) (P0.1 exit criterion).
- Every edge-case register entry's owning document file exists under `docs/` (P0.3 exit criterion).
- E0.2's chosen skill appears in the skill list after a restart and completes one task against the E0.1 sandbox, with the security read recorded (E0.2 exit criterion).
- Settings check (P0.2) is run against the exported Windows release build: all 16 collision layer names, the full input map including number keys 1-7 and debug toggles, and pinned Godot 4.7.1 export templates present.
- `docs/28_AI_Development_Workflow.md` reaches 1.0.0, naming the chosen primary connection method and its fallback, pinning both Godot MCP servers to exact versions, and recording the installed skill(s) with verification results; doc lint clean; every Owns entry resolved or accepted; committed (P0.5 exit criterion).

Whether each of these has in fact been reached is for the critical agents and the phase reviewer to record in REVIEW.md, not for this plan to assert in advance.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| An MCP server version drifts from the pinned engine (Risk Register: "Godot MCP servers drift from the pinned engine version") | Neither server is pinned yet; a fresh `@latest` install or an auto-update between sessions can pull a version built against a different Godot API | Pin both servers to exact versions in P0.5/docs/28 as soon as E0.1 chooses them; avoid `@latest` in any install command from that point on | The pinned version string in docs/28 is checked against the server's actually reported version at the start of each later phase |
| An MCP server silently does nothing rather than erroring | Some bridge-style tools return a success-shaped response even when the underlying editor call was a no-op (wrong scene open, stale node path) | Every E0.1 matrix row requires positive evidence (a screenshot, a read-back value, a file diff), not just a non-error return | Cross-check the claimed effect with a second, independent read call (e.g. read the scene back after saving it) |
| The sandbox project is committed by accident | `sandbox/` sits under `D:\Gamedev`; a broad `git add` sweeps it in | `sandbox/` is listed in `.gitignore` in P0.1, which runs before E0.1 creates any sandbox content | `git status` before every commit; `git log --stat` reviewed for any `sandbox/` path |
| A skill adds its own MCP server or hook with unreviewed network access | Skill packages can bundle settings changes, MCP server definitions, or hooks that call out to a remote service | E0.2's security read covers every script and hook, not only SKILL.md; anything with an unexplained network call is rejected | Diff `.claude/settings.json` and any added skill folder against its pre-install state; search for HTTP/socket calls before installing |
| Godot's editor holds a file lock so a scripted write fails | The editor keeps `project.godot`, `.tscn`, and `.tres` files open with a hot-reload watch; a concurrent MCP write can collide | Prefer editor-integrated MCP calls over raw file writes where both exist; close or reload the editor between conflicting operations | A write call reports success but a re-read of the file, or the editor's own reload, does not reflect it |
| The 4.7.1 export templates are not installed, so P0.2's export step fails | Export templates are a separate download from the editor and are not guaranteed present just because the editor executables are | Confirmed on 2026-09-17: `%APPDATA%\Godot\export_templates` existed but was empty. The author authorised downloading the official `Godot_v4.7.1-stable_export_templates.tpz` (1,280,486,955 bytes, from the godotengine/godot 4.7.1-stable release) and installing it to `%APPDATA%\Godot\export_templates\4.7.1.stable`, which is a write outside the project made under that explicit authorisation. P0.2 re-verifies the templates before exporting rather than trusting this record | `version.txt` in the templates folder reads `4.7.1.stable`, and the Windows release export in P0.2 succeeds |
| A bridge addon needs a port already in use | GDScript LSP (6005), DAP (6006), and the remote debugger (6007) are fixed defaults; another Godot instance or a stale process can already hold one | E0.1's matrix records the port-already-in-use case explicitly, with recovery steps (kill the stale process, or fall back to the named fallback method) | A connection-refused or address-in-use error surfaces during the matrix run |
| Subagents lack the tool permissions the main session has | `.claude/settings.json` permissions may resolve differently in a subagent context | E0.1's matrix explicitly tests whether Sonnet and Opus subagents can call the same tools, before either is relied on in a later phase | A subagent's tool call is denied or errors where the main session's identical call succeeds |
| The failed `filesystem`/`maestro` MCP connections mask a capability the matrix assumes | Both servers failed to connect (30 second timeout) on 2026-09-17; NEXT_SESSION.md Prompt 2 lists a filesystem MCP among this project's configured servers, but CLAUDE.md > Tools does not mention it at all | E0.1 records whether the filesystem server is needed for any matrix item at all, and re-attempts the connection rather than assuming it unavailable for the whole phase | A matrix row fails in a way that traces back to a missing filesystem call rather than a Godot MCP call |
| docs/19's Input Map did not name debug-toggle key bindings | The Settings check (P0.2) requires "debug toggles" in the input map, but docs/19 > Input Map listed only gameplay bindings; the only debug toggle found (pseudo-localization) had no bound key | Closed 2026-09-17 by the author: F1 toggles the debug overlay, F2 toggles pseudo-localization, keyboard only, now recorded in docs/19 > Input Map and as decision D78. P0.2 binds exactly these two and invents no others | The Settings check reads the exported build's input map and finds both toggle actions present |
| A plan or design change lands without a Review Decision Log row | CLAUDE.md requires every design change to carry a row naming the alternative considered | Closed for this phase's own change: the 2026-09-17 addition of E0.1 and E0.2 is recorded as decision D77 in MASTER_SDLC.md, with a Change Log row at 0.8.1 and matching dependency updates on P0.2 and P0.5. Any further plan or design change made during this phase gets its own row before the review gate | Search the Review Decision Log for a row covering each design change made in this phase |

## Agent assignment

- Sonnet subagents do the research (E0.1's method comparison, E0.2's candidate comparison), the writing (docs/28's "Godot Connection" section and full 1.0.0 pass, the 26 P0.3 stubs), and the implementation (git init, the connection-test matrix runs, the skill security read and install, the Godot project skeleton).
- One Opus critical agent per task in this phase checks that task against its plan steps and acceptance test above using real evidence (files, logs, screenshots), and scores it out of 10, at the review gate.
- One Opus phase reviewer scores this phase's execution as a whole against this PLAN.md and the master plan, at the review gate.
- Both kinds of Opus reviewer see PLAN.md, LEDGER.md, and the artifacts; they do not see the implementer's reasoning.

## Open questions for the author

- The exact `/plugin marketplace` commands E0.2 produces (for example `/plugin marketplace add Randroids-Dojo/Godot-Claude-Skills` and `/plugin install godot`, if that candidate is chosen) are typed by the author only; this plan does not run them.
- Approval is needed before: opening any port beyond localhost, installing any software outside the project, or deleting any files (E0.1's stop rule, which also governs E0.2).
- (Closed 2026-09-17) docs/19 > Input Map named no debug-toggle key bindings. The author bound F1 to the debug overlay and F2 to pseudo-localization, keyboard only; docs/19 > Input Map now records them, and the decision is D78.
- (Closed 2026-09-17) The addition of E0.1 and E0.2 to the Development Phase Map is recorded as decision D77 in MASTER_SDLC.md's Review Decision Log, naming the alternative considered, with a Change Log row at 0.8.1.
- Whether the `filesystem` MCP server is actually required for any Phase 00 work, given it failed to connect on 2026-09-17 - E0.1 is scoped to answer this through testing, but the author may already know, which would save that part of the research step.
- P0.2's owner column reads "20 (consults 23)", but document 23 (Folder Structure) has no content beyond a one-line remit at this point in the phase, since nothing in the Development Phase Map appears to write it before P0.2 needs a folder layout. Is P0.2 expected to set the layout from its own judgment (for doc 23 to describe afterward), or does doc 23 need real content first?
